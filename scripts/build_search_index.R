# ===========================================================================
# build_search_index.R — build the small, bundled "Search the network" index.
#
# READS the committed bundles (data/sites/*.rds) + data/site_index.rds — NO live
# fetch. Writes data/search_index.rds, one small file loaded once at boot (like
# site_index), so the Search tab filters it in memory and stays instant.
#
# The index is a list(taxa, sites):
#   taxa  — one row per (scientificName x site): genus, is_culex, the per-site
#           MEASURE (activity index = whole-trap-scaled count / trap-nights, the
#           app's honest within-site unit, from vector_board), ubiquity (% of
#           attempted occasions present), total catch, and year_min/year_max.
#           This drives FIND-A-TAXON.
#   sites — the site-level metrics (reuse site_index) + culex_share, for the
#           THRESHOLD query (Culex share > X%, activity index > X / trap-night).
#
# Run: "/c/Program Files/R/R-4.5.2/bin/Rscript.exe" scripts/build_search_index.R
# ===========================================================================
suppressWarnings(suppressMessages({ library(dplyr) }))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# reuse the SINGLE measure builder so the Search index never diverges from the
# Swarm Board / hero (the single-builder-precompute rule).
source("R/mos_helpers.R", local = TRUE)

SITE_DIR <- "data/sites"
stopifnot(dir.exists(SITE_DIR))
si <- readRDS("data/site_index.rds")

files <- list.files(SITE_DIR, pattern = "\\.rds$", full.names = TRUE)
if (!length(files)) stop("No bundles in ", SITE_DIR, " — run scripts/bundle_mos_data.R first.")

taxa_rows <- list()
site_rows <- list()
for (f in files) {
  site <- sub("\\.rds$", "", basename(f))
  b <- tryCatch(readRDS(f), error = function(e) NULL)
  if (is.null(b) || is.null(b$obs) || !nrow(b$obs)) next
  tn   <- b$meta$trap_nights %||% (if (!is.null(b$traps$trap_nights)) sum(b$traps$trap_nights, na.rm = TRUE) else NA_real_)
  nocc <- b$meta$n_occ_attempted %||% dplyr::n_distinct(b$obs$sampleID)

  # per-(species x this site) measure — exactly the Swarm Board's index + ubiquity
  brd <- vector_board(b$obs, n_occ = nocc, trap_nights = tn)
  if (!is.null(brd) && nrow(brd)) {
    # year range a species was actually caught at this site
    sp <- target_only(species_level_only(b$obs))
    yr <- sp %>% dplyr::group_by(.data$scientificName) %>%
      dplyr::summarise(year_min = suppressWarnings(min(.data$year, na.rm = TRUE)),
                       year_max = suppressWarnings(max(.data$year, na.rm = TRUE)), .groups = "drop")
    taxa_rows[[site]] <- brd %>%
      dplyr::transmute(
        scientificName = .data$scientificName,
        genus = .data$genus,
        is_culex = .data$genus == "Culex",
        site = site,
        activity_index = .data$index,       # within-site activity index (per trap-night)
        ubiquity = .data$ubiquity,          # % of attempted occasions present
        total = round(.data$total)) %>%
      dplyr::left_join(yr, by = "scientificName")
  }

  # site-level row for the threshold query: reuse site_index + add culex_share
  sr <- si[si$site == site, , drop = FALSE]
  if (nrow(sr)) {
    tg <- target_only(species_level_only(b$obs))
    culex <- sum(num(tg$count[tg$genus == "Culex"]), na.rm = TRUE)
    tot   <- sum(num(tg$count), na.rm = TRUE)
    sr$culex_share <- if (tot > 0) round(100 * culex / tot, 1) else NA_real_
    site_rows[[site]] <- sr
  }
}

taxa  <- dplyr::bind_rows(taxa_rows)
sites <- dplyr::bind_rows(site_rows)
# tidy: drop NA/empty names, sort taxa for a clean autocomplete
taxa <- taxa[!is.na(taxa$scientificName) & nzchar(taxa$scientificName), , drop = FALSE]
taxa <- taxa[order(taxa$scientificName, dplyr::desc(taxa$activity_index)), , drop = FALSE]
sites <- sites[order(sites$site), , drop = FALSE]

out <- list(taxa = taxa, sites = sites, built = as.character(Sys.Date()))
saveRDS(out, "data/search_index.rds", compress = "xz")

sz <- file.info("data/search_index.rds")$size
cat(sprintf("Wrote data/search_index.rds — %d taxon-site rows, %d distinct taxa across %d sites; %.1f KB\n",
            nrow(taxa), dplyr::n_distinct(taxa$scientificName), dplyr::n_distinct(taxa$site), sz / 1024))
cat("Culex rows:", sum(taxa$is_culex), " | sites with culex_share:", sum(!is.na(sites$culex_share)), "\n")
