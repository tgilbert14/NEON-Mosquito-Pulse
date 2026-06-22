# ===========================================================================
# bundle_mos_data.R — bundle NEON CO2-trap mosquitoes (DP1.10043.001) into
# per-site .rds. Reads ../mosquito-data-fetch/<SITE>_raw.rds (fetch_mos_all.R).
# Each bundle = list(obs, traps, meta):
#   obs   — one row per identified (subsample x species x sex) lot: sampleID,
#           trapkey, plotID, trapID, year, collectDate, week, scientificName,
#           genus, sex, is_species, is_target, count (WHOLE-TRAP-SCALED), plus the
#           QC context (trapHours, targetTaxaPresent, sampleCondition, nightOrDay,
#           subsampleWeight, totalWeight, expansionFactor, identificationQualifier).
#   traps — one row per trap: trapkey, plotID, trapID, nlcdClass, lat, lng,
#           trap_nights (sum trapHours/24), n_collections.  THE effort table.
#   meta  — site, lat, lng, years, trap_nights (site total), n_traps.
# Activity index = sum(count, target) / trap_nights = mosquitoes per trap-night.
#
# This is the SINGLE builder of the trap-night index + site_index.rds (the
# single-builder-precompute rule): the app never recomputes a divergent index.
# ===========================================================================
suppressWarnings(suppressMessages({ library(dplyr) }))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
mode_chr <- function(x) { x <- x[!is.na(x)]; if (!length(x)) return(NA_character_); names(sort(table(x), decreasing = TRUE))[1] }
num <- function(x) suppressWarnings(as.numeric(x))
pk  <- function(plot, t) paste(plot, t, sep = "_")
RAW <- "../mosquito-data-fetch"; DEMO <- "SRER"
SITES <- sort(sub("_raw\\.rds$", "", list.files(RAW, pattern = "_raw\\.rds$")))
if (!length(SITES)) stop("No <SITE>_raw.rds in ", RAW, " — run scripts/fetch_mos_all.R first.")
cat(sprintf("Bundling %d sites: %s\n", length(SITES), paste(SITES, collapse = " ")))

is_species_rank <- function(rank, sci) {
  ok <- is.na(rank) | rank %in% c("species", "subspecies")
  amb <- grepl("\\bsp\\.?$", ifelse(is.na(sci), "", sci)) | grepl("/", ifelse(is.na(sci), "", sci), fixed = TRUE)
  ok & !amb
}
CLEAN <- c("OK", "No known compromise", "good")

build_site <- function(site) {
  f <- file.path(RAW, paste0(site, "_raw.rds")); if (!file.exists(f)) { cat("  MISSING", f, "\n"); return(NULL) }
  r <- readRDS(f)
  idd <- tibble::as_tibble(r$mos_expertTaxonomistIDProcessed)
  srt <- tibble::as_tibble(r$mos_sorting)
  trp <- tibble::as_tibble(r$mos_trapping)

  # subsample expansion: NEON identifies a PROPORTION of a big catch (mos_sorting
  # $proportionIdentified), so scale the identified count up to the whole trap by
  # 1 / proportionIdentified. (The real product has no totalWeight/subsampleWeight.)
  sort_map <- srt %>%
    dplyr::transmute(subsampleID, sampleID,
                     proportionIdentified = num(.data$proportionIdentified),
                     scale = ifelse(num(.data$proportionIdentified) > 0, 1 / num(.data$proportionIdentified), 1))
  # trap deployment context = the effort table (one row per sampleID = one trap-night).
  # DP1.10043.001 has NO trapID: one CO2 trap per plotID per collection.
  trap_ctx <- trp %>%
    dplyr::transmute(sampleID, plotID,
                     collectDate = as.Date(substr(as.character(.data$collectDate), 1, 10)),
                     trapHours = num(.data$trapHours),
                     nightOrDay = tolower(as.character(.data$nightOrDay)),
                     targetTaxaPresent = as.character(.data$targetTaxaPresent),
                     sampleCondition = as.character(.data$sampleCondition),
                     lat = num(.data$decimalLatitude), lng = num(.data$decimalLongitude),
                     nlcdClass = as.character(.data$nlcdClass))

  obs <- idd %>%
    dplyr::select(subsampleID, plotID, collectDate, taxonID, scientificName, taxonRank,
                  family, genus, sex, individualCount, nativeStatusCode, identificationQualifier) %>%
    dplyr::left_join(sort_map, by = "subsampleID") %>%
    dplyr::left_join(trap_ctx %>% dplyr::distinct(.data$sampleID, .keep_all = TRUE) %>%
                       dplyr::select(sampleID, trapHours, nightOrDay, targetTaxaPresent, sampleCondition),
                     by = "sampleID") %>%
    dplyr::filter(!is.na(.data$scientificName), num(.data$individualCount) > 0, !is.na(.data$sampleID)) %>%
    dplyr::transmute(
      sampleID, trapkey = .data$plotID, plotID = .data$plotID,
      trapID = sub("^[A-Z]{4}_", "", .data$plotID),
      # occ_id = the trap-night occasion (plotID + collect date), the SAME key the
      # effort frame uses, so the catch numerator and the effort denominator agree.
      occ_id = paste(.data$plotID, as.Date(substr(as.character(.data$collectDate), 1, 10))),
      year = as.integer(substr(as.character(.data$collectDate), 1, 4)),
      collectDate = as.Date(substr(as.character(.data$collectDate), 1, 10)),
      week = as.integer(format(as.Date(substr(as.character(.data$collectDate), 1, 10)), "%U")),
      taxonID, scientificName, vernacularName = NA_character_, taxonRank,
      is_species = is_species_rank(.data$taxonRank, .data$scientificName),
      genus = ifelse(!is.na(.data$genus) & nzchar(.data$genus), .data$genus, sub(" .*", "", .data$scientificName)),
      sex = toupper(substr(as.character(.data$sex), 1, 1)),
      nativeStatusCode,
      count = num(.data$individualCount) * ifelse(is.finite(.data$scale), .data$scale, 1),   # whole-trap scaled
      is_target = is.na(.data$family) | .data$family == "Culicidae",
      nightOrDay, trapHours, targetTaxaPresent, sampleCondition,
      proportionIdentified, expansionFactor = round(ifelse(is.finite(.data$scale), .data$scale, 1), 2),
      identificationQualifier) %>%
    dplyr::filter(!is.na(.data$year))
  obs$sex[!(obs$sex %in% c("F","M"))] <- "U"; obs$vernacularName <- NA_character_

  # traps (effort) = one row per plotID
  traps <- trap_ctx %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(trapID = sub("^[A-Z]{4}_", "", dplyr::first(.data$plotID)),
                     nlcdClass = mode_chr(.data$nlcdClass),
                     lat = stats::median(.data$lat, na.rm = TRUE), lng = stats::median(.data$lng, na.rm = TRUE),
                     collectDate = suppressWarnings(max(.data$collectDate, na.rm = TRUE)),
                     trap_nights = sum(ifelse(is.finite(.data$trapHours) & .data$trapHours > 0, .data$trapHours, 0), na.rm = TRUE) / 24,
                     n_collections = dplyr::n_distinct(.data$sampleID), .groups = "drop") %>%
    dplyr::mutate(trapkey = .data$plotID)
  # ONE shared deployment-level effort frame (the single-builder rule). Every
  # trapping row is a real trap-night INCLUDING the zero-catch nights, which carry
  # NA sampleID -> they MUST be keyed on the trap-night identity (plotID, collectDate),
  # not on sampleID, or distinct(sampleID) collapses all ~3.8k of them into one row
  # and the pulse denominator drops ~5x below the hero denominator (same "/trap-night"
  # label, irreconcilable). effort_week, meta$trap_nights, and n_occ_attempted all
  # derive from THIS frame, and obs$occ_id uses the same key, so the catch numerator
  # and the effort denominator are on one consistent unit (a trap-night).
  eff <- trap_ctx %>% dplyr::transmute(
      occ_id = paste(.data$plotID, .data$collectDate),
      year = as.integer(substr(as.character(.data$collectDate), 1, 4)),
      week = as.integer(format(.data$collectDate, "%U")),
      trap_nights = ifelse(is.finite(.data$trapHours) & .data$trapHours > 0, .data$trapHours / 24, 0))
  effort_week <- eff %>% dplyr::filter(!is.na(.data$year), !is.na(.data$week)) %>%
    dplyr::group_by(.data$year, .data$week) %>%
    dplyr::summarise(trap_nights = sum(.data$trap_nights, na.rm = TRUE), .groups = "drop")
  meta <- list(site = site, lat = stats::median(traps$lat, na.rm = TRUE), lng = stats::median(traps$lng, na.rm = TRUE),
               years = sort(unique(obs$year)),
               trap_nights = round(sum(eff$trap_nights, na.rm = TRUE), 1),
               n_occ_attempted = dplyr::n_distinct(eff$occ_id[eff$trap_nights > 0]), n_traps = nrow(traps))
  list(obs = obs, traps = traps, effort_week = effort_week, meta = meta)
}

dir.create("data/sites", showWarnings = FALSE, recursive = TRUE); dir.create("data-sample", showWarnings = FALSE)
idx <- list()
for (s in SITES) {
  cat("=== bundling", s, "===\n"); b <- build_site(s); if (is.null(b) || !nrow(b$obs)) next
  saveRDS(b, file.path("data/sites", paste0(s, ".rds")), compress = "xz")
  if (identical(s, DEMO)) saveRDS(b, file.path("data-sample", "demo.rds"), compress = "xz")
  tg <- b$obs[b$obs$is_target %in% TRUE & b$obs$is_species %in% TRUE, ]
  sp_tot <- tapply(tg$count, tg$scientificName, sum); top <- names(sp_tot)[which.max(sp_tot)]
  idx[[s]] <- data.frame(site = s, taxa = length(unique(tg$scientificName)),
    individuals = round(sum(tg$count)), collections = b$meta$n_occ_attempted %||% length(unique(b$obs$sampleID)),
    trap_nights = b$meta$trap_nights, mos_per_tn = round(sum(tg$count) / max(1, b$meta$trap_nights), 2),
    top_taxon = top, top_genus = sub(" .*", "", top %||% "NA"),
    lat = b$meta$lat, lng = b$meta$lng,
    year_min = min(b$meta$years), year_max = max(b$meta$years), stringsAsFactors = FALSE)
  cat(sprintf("  %s: %d species, %d traps, %.0f trap-nights, %.2f / trap-night, top %s\n",
      s, idx[[s]]$taxa, b$meta$n_traps, b$meta$trap_nights, idx[[s]]$mos_per_tn, top))
}
saveRDS(dplyr::bind_rows(idx), "data/site_index.rds", compress = "xz")
cat("\nWrote data/site_index.rds\n"); print(dplyr::bind_rows(idx)[, c("site","taxa","mos_per_tn","top_taxon")]); cat("DONE\n")
