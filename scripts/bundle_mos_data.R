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

  # subsample weight ratio: scale identified counts up to the whole trap
  sort_ratio <- srt %>%
    dplyr::transmute(subsampleID, sampleID,
                     sampleType = .data$sampleType %||% NA_character_,
                     subsampleWeight = num(.data$subsampleWeight), totalWeight = num(.data$totalWeight),
                     scale = ifelse(num(.data$subsampleWeight) > 0 & is.finite(num(.data$totalWeight)),
                                    num(.data$totalWeight) / num(.data$subsampleWeight), 1))
  trap_ctx <- trp %>%
    dplyr::transmute(sampleID, plotID, trapID,
                     collectDate = as.Date(substr(as.character(.data$collectDate), 1, 10)),
                     trapHours = num(.data$trapHours),
                     nightOrDay = tolower(.data$nightOrDay %||% NA_character_),
                     targetTaxaPresent = .data$targetTaxaPresent %||% NA_character_,
                     sampleCondition = .data$sampleCondition %||% NA_character_,
                     lat = num(.data$decimalLatitude), lng = num(.data$decimalLongitude),
                     nlcdClass = .data$nlcdClass %||% NA_character_)

  obs <- idd %>%
    dplyr::left_join(sort_ratio, by = "subsampleID") %>%
    dplyr::left_join(trap_ctx %>% dplyr::distinct(sampleID, .keep_all = TRUE), by = "sampleID") %>%
    dplyr::filter(!is.na(.data$scientificName), num(.data$individualCount) > 0) %>%
    dplyr::transmute(
      sampleID, trapkey = pk(.data$plotID, .data$trapID), plotID, trapID,
      year = as.integer(substr(as.character(.data$collectDate), 1, 4)), collectDate,
      week = as.integer(format(.data$collectDate, "%U")),
      taxonID = .data$taxonID %||% NA_character_, scientificName, vernacularName = .data$vernacularName %||% NA_character_,
      taxonRank = .data$taxonRank %||% NA_character_,
      is_species = is_species_rank(.data$taxonRank, .data$scientificName),
      genus = sub(" .*", "", .data$scientificName),
      sex = toupper(substr(.data$sex %||% "U", 1, 1)),
      nativeStatusCode = .data$nativeStatusCode %||% NA_character_,
      count = num(.data$individualCount) * ifelse(is.finite(.data$scale), .data$scale, 1),   # whole-trap scaled
      is_target = !grepl("bycatch|other|non-?target", tolower(.data$sampleType %||% "")) ,
      nightOrDay, trapHours, targetTaxaPresent, sampleCondition,
      subsampleWeight = .data$subsampleWeight, totalWeight = .data$totalWeight,
      expansionFactor = round(ifelse(is.finite(.data$scale), .data$scale, 1), 2),
      identificationQualifier = .data$identificationQualifier %||% "") %>%
    dplyr::filter(!is.na(.data$year))
  obs$sex[!(obs$sex %in% c("F","M"))] <- "U"

  traps <- trap_ctx %>% dplyr::mutate(trapkey = pk(.data$plotID, .data$trapID)) %>%
    dplyr::group_by(.data$trapkey) %>%
    dplyr::summarise(plotID = mode_chr(.data$plotID), trapID = mode_chr(.data$trapID),
                     nlcdClass = mode_chr(.data$nlcdClass),
                     lat = stats::median(.data$lat, na.rm = TRUE), lng = stats::median(.data$lng, na.rm = TRUE),
                     collectDate = max(.data$collectDate, na.rm = TRUE),
                     trap_nights = sum(ifelse(is.finite(.data$trapHours) & .data$trapHours > 0, .data$trapHours, 0), na.rm = TRUE) / 24,
                     n_collections = dplyr::n_distinct(.data$sampleID), .groups = "drop")
  # ATTEMPTED collection occasions (one row per sampleID in the trapping table,
  # INCLUDING zero-catch nights) -> the honest pulse / ubiquity denominator.
  occ <- trap_ctx %>% dplyr::distinct(.data$sampleID, .keep_all = TRUE) %>%
    dplyr::transmute(sampleID,
                     year = as.integer(substr(as.character(.data$collectDate), 1, 4)),
                     week = as.integer(format(.data$collectDate, "%U")),
                     trap_nights = ifelse(is.finite(.data$trapHours) & .data$trapHours > 0, .data$trapHours / 24, 0))
  effort_week <- occ %>% dplyr::filter(!is.na(.data$year), !is.na(.data$week)) %>%
    dplyr::group_by(.data$year, .data$week) %>%
    dplyr::summarise(trap_nights = sum(.data$trap_nights, na.rm = TRUE), .groups = "drop")
  meta <- list(site = site, lat = stats::median(traps$lat, na.rm = TRUE), lng = stats::median(traps$lng, na.rm = TRUE),
               years = sort(unique(obs$year)),
               trap_nights = round(sum(traps$trap_nights, na.rm = TRUE), 1),
               n_occ_attempted = dplyr::n_distinct(trap_ctx$sampleID), n_traps = nrow(traps))
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
