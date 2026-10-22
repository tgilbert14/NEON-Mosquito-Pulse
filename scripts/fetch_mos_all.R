#!/usr/bin/env Rscript
# Fetch the immutable pinned NEON release (R/mos_release.R) into an isolated staging area.
options(timeout = 3600)
suppressPackageStartupMessages(library(neonUtilities))
source("R/mos_release.R")
source("R/site_metadata.R")

product <- MOS_RELEASE$product
release <- Sys.getenv("MOS_RELEASE", MOS_RELEASE$release)
if (!identical(release, MOS_RELEASE$release)) stop("Release must be ", MOS_RELEASE$release,
  " (R/mos_release.R); change that file to move releases", call. = FALSE)
start_month <- MOS_RELEASE$start_month
end_month <- MOS_RELEASE$end_month
out_dir <- Sys.getenv("MOS_RAW_DIR", "../mosquito-data-fetch")
token <- Sys.getenv("NEON_TOKEN", "")
if (!nzchar(token)) stop("NEON_TOKEN is empty; NEON data endpoints refuse anonymous requests (see .env.example)", call. = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

sites <- sort(unique(as.character(neon_sites$site)))
args <- commandArgs(trailingOnly = TRUE)
subset_run <- length(args) > 0L
if (subset_run) sites <- intersect(sites, toupper(args))
if (!length(sites)) stop("No requested sites are in the canonical roster", call. = FALSE)
cat(sprintf("Fetching %s %s for %d sites (%s through %s)\n",
            product, release, length(sites), start_month, end_month))

# NEON's own per-site coverage for this release, from the anonymous products
# endpoint. verify_bundle.R gates every bundle's coverage against it.
product_meta <- jsonlite::fromJSON(sprintf(
  "https://data.neonscience.org/api/v0/products/%s?release=%s", product, release))$data$siteCodes
available <- setNames(lapply(product_meta$availableMonths, function(m) sort(as.character(m))),
                      product_meta$siteCode)
missing_coverage <- setdiff(sites, names(available)[lengths(available) > 0L])
if (length(missing_coverage)) stop("NEON lists no ", release, " availableMonths for: ",
                                   paste(missing_coverage, collapse = ", "), call. = FALSE)

# Fixed row order on NEON's uid so the staged raw file and its md5 do not
# change when neonUtilities returns the same release in a different order.
mos_sort_raw <- function(raw) {
  for (t in names(raw)) {
    d <- raw[[t]]
    if (is.data.frame(d) && "uid" %in% names(d)) {
      d <- d[order(d$uid, method = "radix"), , drop = FALSE]
      rownames(d) <- NULL
      raw[[t]] <- d
    }
  }
  raw
}

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
        token = token
      ),
      error = function(e) stop(site, " fetch failed: ", conditionMessage(e), call. = FALSE)
    )
    raw <- mos_sort_raw(raw)
    saveRDS(raw, path, compress = "xz", version = 3)
  }
  required <- c("mos_trapping", "mos_sorting", "mos_expertTaxonomistIDProcessed")
  missing <- setdiff(required, names(raw))
  if (length(missing)) stop(site, " missing release tables: ", paste(missing, collapse = ", "), call. = FALSE)
  rows[[site]] <- data.frame(
    product = product, release = release, doi = MOS_RELEASE$doi,
    release_generated = MOS_RELEASE$release_generated, site = site,
    trapping_rows = nrow(raw$mos_trapping), sorting_rows = nrow(raw$mos_sorting),
    identification_rows = nrow(raw$mos_expertTaxonomistIDProcessed),
    raw_md5 = unname(tools::md5sum(path)),
    available_first_month = available[[site]][1L],
    available_last_month = available[[site]][length(available[[site]])],
    available_month_count = length(available[[site]]),
    stringsAsFactors = FALSE
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
