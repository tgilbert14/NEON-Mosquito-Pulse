#!/usr/bin/env Rscript
# Fail-closed verification of opportunity-complete bundles and deploy bytes.
suppressMessages(library(jsonlite))
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a
source("R/site_metadata.R")
problems <- character(0)
note <- function(x) problems[[length(problems)+1L]] <<- x
expected <- sort(unique(as.character(neon_sites$site)))
files <- sort(list.files("data/sites", pattern="[.]rds$", full.names=TRUE))
sites <- sub("[.]rds$", "", basename(files))
if (!identical(sites, expected)) note(sprintf("site roster mismatch missing=[%s] extra=[%s]",
  paste(setdiff(expected, sites), collapse=","), paste(setdiff(sites, expected), collapse=",")))

totals <- c(rows=0, effort=0, valid=0, zero=0, catch=0, held=0)
for (file in files) {
  site <- sub("[.]rds$", "", basename(file))
  b <- tryCatch(readRDS(file), error=function(e)e)
  if (inherits(b,"error") || !is.list(b)) { note(paste(site,"unreadable")); next }
  missing <- setdiff(c("obs","effort","traps","effort_week","held_identifications","meta"), names(b))
  if (length(missing)) { note(paste(site,"missing bundle members",paste(missing,collapse=","))); next }
  er <- b$effort; ob <- b$obs
  er_req <- c("effort_id","sampleID","plotID","collectDate","nightOrDay","trapHours","valid_effort",
              "effort_status","effort_days","outcome_status","zero_catch","target_count","protocol_era")
  ob_req <- c("sampleID","effort_id","occ_id","plotID","collectDate","taxonRank","is_species",
              "scientificName","count","is_target","proportionIdentified","expansionFactor")
  if (length(setdiff(er_req,names(er)))) note(paste(site,"effort schema incomplete"))
  if (length(setdiff(ob_req,names(ob)))) note(paste(site,"observation schema incomplete"))
  if (!nrow(er) || anyDuplicated(er$effort_id)) note(paste(site,"missing or duplicate effort identity"))
  valid <- er[er$valid_effort %in% TRUE,,drop=FALSE]
  if (!nrow(valid)) note(paste(site,"has no valid opportunities"))
  if (nrow(valid) && any(!is.finite(valid$trapHours) | valid$trapHours<=0 |
                         abs(valid$effort_days-valid$trapHours/24)>1e-10)) note(paste(site,"invalid effort conversion"))
  if (any(er$zero_catch != (er$outcome_status=="zero_catch"), na.rm=TRUE)) note(paste(site,"zero-catch classification mismatch"))
  if (any(er$zero_catch & !(toupper(substr(er$targetTaxaPresent,1,1)) %in% "N"), na.rm=TRUE)) note(paste(site,"unsupported zero catch"))
  if (nrow(ob)) {
    if (any(!is.finite(ob$count) | ob$count<=0 | !is.finite(ob$proportionIdentified) |
            ob$proportionIdentified<=0 | ob$proportionIdentified>1 |
            abs(ob$expansionFactor-(1/ob$proportionIdentified))>1e-10)) note(paste(site,"invalid expanded catch"))
    if (any(!(ob$effort_id %in% valid$effort_id))) note(paste(site,"catch without valid effort"))
    if (any(ob$occ_id != ob$effort_id)) note(paste(site,"incidence key differs from effort key"))
  }
  if (!identical(as.character(b$meta$release),"RELEASE-2026") ||
      !identical(as.character(b$meta$product),"DP1.10043.001")) note(paste(site,"wrong release identity"))
  if (!isTRUE(all.equal(as.numeric(b$meta$effort_days),sum(valid$effort_days)))) note(paste(site,"meta effort mismatch"))
  if (!identical(as.integer(b$meta$n_occ_attempted),as.integer(nrow(valid)))) note(paste(site,"meta opportunity mismatch"))
  if (!identical(as.integer(b$meta$n_zero_catch),as.integer(sum(valid$zero_catch)))) note(paste(site,"meta zero mismatch"))
  totals <- totals + c(nrow(ob)+nrow(er),nrow(er),nrow(valid),sum(valid$zero_catch),nrow(ob),nrow(b$held_identifications))
}

index <- tryCatch(readRDS("data/site_index.rds"), error=function(e)e)
if (inherits(index,"error") || !is.data.frame(index) ||
    !identical(sort(as.character(index$site)),expected)) note("site_index roster mismatch")
receipt <- tryCatch(utils::read.csv("data/source-receipt.csv", stringsAsFactors=FALSE), error=function(e)e)
if (inherits(receipt,"error") || !is.data.frame(receipt) ||
    !identical(sort(as.character(receipt$site)),expected) ||
    any(receipt$release != "RELEASE-2026") || any(receipt$product != "DP1.10043.001") ||
    any(receipt$doi != "10.48443/rmw1-me46")) note("source receipt is missing or not exact RELEASE-2026")
for (path in c("data/cross_site.rds","data/search_index.rds","data/site_climate.rds","data/site_month_clim.rds"))
  if (!file.exists(path)) note(paste("missing derived index",path))

manifest <- tryCatch(jsonlite::fromJSON("manifest.json",simplifyVector=FALSE), error=function(e)e)
if (inherits(manifest,"error")) note("manifest unreadable") else {
  mf <- manifest$files
  missing <- names(mf)[!file.exists(names(mf))]
  if (length(missing)) note(paste("manifest missing files",paste(missing,collapse=",")))
  present <- setdiff(names(mf),missing)
  bad <- vapply(present,function(path)!identical(tolower(as.character(mf[[path]]$checksum %||% "")),
                                               tolower(unname(tools::md5sum(path)))),logical(1))
  if (any(bad)) note(paste("manifest checksum mismatch",paste(present[bad],collapse=",")))
  if (!identical(as.character(manifest$platform %||% ""),"4.5.2")) note("manifest R platform mismatch")
  repos <- vapply(manifest$packages,function(x)as.character(x$Repository %||% ""),character(1))
  allowed <- c("https://packagemanager.posit.co/cran/__linux__/jammy/2026-07-15","https://cran.r-project.org")
  if (any(!(repos %in% allowed))) note("manifest contains moving package source")
  if (length(intersect(names(manifest$packages),c("neonUtilities","arrow")))) note("manifest leaks build-only packages")
}
cat(sprintf("bundles: %d files, %d rows, %d valid opportunities, %d supported zeros, %d catch rows, %d held rows\n",
            length(files),totals[["rows"]],totals[["valid"]],totals[["zero"]],totals[["catch"]],totals[["held"]]))
if (length(problems)) {
  for (problem in unique(problems)) cat(sprintf("::error title=Mosquito verification::%s\n",problem))
  stop(sprintf("Mosquito verification FAILED with %d problem(s)",length(unique(problems))),call.=FALSE)
}
cat("OK: Mosquito release, opportunities, zeros, indexes, and manifest passed.\n")
