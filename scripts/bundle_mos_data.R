#!/usr/bin/env Rscript
# Build opportunity-complete RELEASE-2026 site bundles from staged raw objects.
suppressWarnings(suppressMessages({
  library(dplyr)
  library(tibble)
}))
source("R/mos_bundle_contract.R")
source("R/mos_helpers.R")

raw_dir <- Sys.getenv("MOS_RAW_DIR", "../mosquito-data-fetch")
out_dir <- Sys.getenv("MOS_SITE_OUT_DIR", "data/sites")
release <- Sys.getenv("MOS_RELEASE", "RELEASE-2026")
demo_site <- "SRER"
files <- sort(list.files(raw_dir, pattern = "_raw[.]rds$", full.names = TRUE))
if (!length(files)) stop("No <SITE>_raw.rds files in ", raw_dir, call. = FALSE)
sites <- sub("_raw[.]rds$", "", basename(files))
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create("data-sample", showWarnings = FALSE, recursive = TRUE)

index <- list()
for (i in seq_along(files)) {
  site <- sites[[i]]
  cat("=== bundling ", site, " ===\n", sep = "")
  bundle <- mos_build_bundle(readRDS(files[[i]]), site, release)
  saveRDS(bundle, file.path(out_dir, paste0(site, ".rds")), compress = "xz", version = 3)
  if (identical(site, demo_site) && identical(normalizePath(out_dir), normalizePath("data/sites")))
    saveRDS(bundle, file.path("data-sample", "demo.rds"), compress = "xz", version = 3)

  target <- target_only(bundle$obs)
  species <- species_level_only(target)
  total <- sum(target$count, na.rm = TRUE)
  species_totals <- if (nrow(species)) tapply(species$count, species$scientificName, sum) else numeric(0)
  top <- if (length(species_totals)) names(which.max(species_totals)) else NA_character_
  index[[site]] <- data.frame(
    site = site,
    taxa = length(unique(species$scientificName)),
    individuals = round(total),
    collections = bundle$meta$n_occ_attempted,
    effort_days = bundle$meta$effort_days,
    trap_nights = bundle$meta$effort_days,
    zero_catches = bundle$meta$n_zero_catch,
    mos_per_24h = if (bundle$meta$effort_days > 0) total / bundle$meta$effort_days else NA_real_,
    mos_per_tn = if (bundle$meta$effort_days > 0) total / bundle$meta$effort_days else NA_real_,
    top_taxon = top,
    top_genus = ifelse(is.na(top), NA_character_, sub(" .*", "", top)),
    lat = bundle$meta$lat,
    lng = bundle$meta$lng,
    year_min = if (length(bundle$meta$years)) min(bundle$meta$years) else NA_integer_,
    year_max = if (length(bundle$meta$years)) max(bundle$meta$years) else NA_integer_,
    stringsAsFactors = FALSE
  )
  cat(sprintf("  %s: %d valid intervals (%d zero catch), %.1f 24h units, %.2f mosquitoes/24h\n",
              site, bundle$meta$n_occ_attempted, bundle$meta$n_zero_catch,
              bundle$meta$effort_days, index[[site]]$mos_per_24h))
}

site_index <- dplyr::bind_rows(index) |> dplyr::arrange(.data$site)
if (identical(normalizePath(out_dir), normalizePath("data/sites"))) {
  saveRDS(site_index, "data/site_index.rds", compress = "xz", version = 3)
} else {
  saveRDS(site_index, file.path(dirname(out_dir), "site_index.rds"), compress = "xz", version = 3)
}
cat(sprintf("DONE: %d sites, %d opportunities, %d zero catches\n",
            nrow(site_index), sum(site_index$collections), sum(site_index$zero_catches)))
