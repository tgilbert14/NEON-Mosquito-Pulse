#!/usr/bin/env Rscript
# Fetch the immutable NEON RELEASE-2026 package into an isolated staging area.
options(timeout = 3600)
suppressPackageStartupMessages(library(neonUtilities))
source("R/site_metadata.R")

product <- "DP1.10043.001"
release <- Sys.getenv("MOS_RELEASE", "RELEASE-2026")
if (!identical(release, "RELEASE-2026")) stop("Release must be RELEASE-2026", call. = FALSE)
start_month <- "2014-01"
end_month <- "2024-12"
out_dir <- Sys.getenv("MOS_RAW_DIR", "../mosquito-data-fetch")
token <- Sys.getenv("NEON_TOKEN", "")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

sites <- sort(unique(as.character(neon_sites$site)))
args <- commandArgs(trailingOnly = TRUE)
subset_run <- length(args) > 0L
if (subset_run) sites <- intersect(sites, toupper(args))
if (!length(sites)) stop("No requested sites are in the canonical roster", call. = FALSE)
cat(sprintf("Fetching %s %s for %d sites (%s through %s)\n",
            product, release, length(sites), start_month, end_month))

rows <- list()
for (site in sites) {
  path <- file.path(out_dir, paste0(site, "_raw.rds"))
  if (file.exists(path)) {
    cat(sprintf("- %-5s existing staged raw file\n", site))
    raw <- readRDS(path)
  } else {
    cat(sprintf("- %-5s fetching immutable release...\n", site)); flush.console()
    raw <- tryCatch(
      loadByProduct(
        dpID = product, site = site, startdate = start_month, enddate = end_month,
        package = "basic", release = release, check.size = "F",
        token = if (nzchar(token)) token else NA_character_
      ),
      error = function(e) stop(site, " fetch failed: ", conditionMessage(e), call. = FALSE)
    )
    saveRDS(raw, path, compress = "xz", version = 3)
  }
  required <- c("mos_trapping", "mos_sorting", "mos_expertTaxonomistIDProcessed")
  missing <- setdiff(required, names(raw))
  if (length(missing)) stop(site, " missing release tables: ", paste(missing, collapse = ", "), call. = FALSE)
  rows[[site]] <- data.frame(
    product = product, release = release, doi = "10.48443/rmw1-me46",
    release_generated = "2026-01-23", site = site,
    trapping_rows = nrow(raw$mos_trapping), sorting_rows = nrow(raw$mos_sorting),
    identification_rows = nrow(raw$mos_expertTaxonomistIDProcessed),
    raw_md5 = unname(tools::md5sum(path)), stringsAsFactors = FALSE
  )
}

built <- sort(sub("_raw[.]rds$", "", list.files(out_dir, pattern = "_raw[.]rds$")))
expected <- sort(unique(as.character(neon_sites$site)))
if (!subset_run && !identical(built, expected)) {
  stop(sprintf("Raw roster incomplete: missing=[%s] extra=[%s]",
               paste(setdiff(expected, built), collapse = ","),
               paste(setdiff(built, expected), collapse = ",")), call. = FALSE)
}

receipt <- do.call(rbind, rows)
receipt <- receipt[order(receipt$site), , drop = FALSE]
receipt_path <- Sys.getenv("MOS_SOURCE_RECEIPT", file.path(dirname(out_dir), "source-receipt.csv"))
utils::write.csv(receipt, receipt_path, row.names = FALSE, na = "")
cat(sprintf("DONE: %d release packages; receipt %s\n", nrow(receipt), receipt_path))
