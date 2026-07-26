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
index_oracle <- list()
for (file in files) {
  site <- sub("[.]rds$", "", basename(file))
  b <- tryCatch(readRDS(file), error=function(e)e)
  if (inherits(b,"error") || !is.list(b)) { note(paste(site,"unreadable")); next }
  missing <- setdiff(c("obs","effort","traps","effort_week","held_identifications","meta"), names(b))
  if (length(missing)) { note(paste(site,"missing bundle members",paste(missing,collapse=","))); next }
  er <- b$effort; ob <- b$obs
  er_req <- c("effort_id","source_uid","eventID","sampleID","plotID","setDate","collectTimestamp","collectDate","nightOrDay","trapHours","valid_effort",
              "effort_status","effort_days","outcome_status","zero_catch","target_count","protocol_era")
  ob_req <- c("sampleID","effort_id","occ_id","plotID","collectDate","taxonRank","is_species",
              "scientificName","count","is_target","proportionIdentified","expansionFactor")
  er_missing <- setdiff(er_req,names(er)); ob_missing <- setdiff(ob_req,names(ob))
  if (length(er_missing)) note(paste(site,"effort schema incomplete"))
  if (length(ob_missing)) note(paste(site,"observation schema incomplete"))
  if (length(er_missing) || length(ob_missing)) next
  if (!nrow(er) || anyDuplicated(er$effort_id)) note(paste(site,"missing or duplicate effort identity"))
  valid <- er[er$valid_effort %in% TRUE,,drop=FALSE]
  if (!nrow(valid)) note(paste(site,"has no valid opportunities"))
  if (nrow(valid)) {
    identity_ok <- !is.na(valid$source_uid) |
      (!is.na(valid$eventID) & !is.na(valid$plotID) & !is.na(valid$setDate) &
         !is.na(valid$collectTimestamp) & !is.na(valid$nightOrDay))
    if (any(!identity_ok)) note(paste(site,"valid opportunity has incomplete physical identity"))
  }
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
      !identical(as.character(b$meta$product),"DP1.10043.001") ||
      !identical(as.character(b$meta$doi),"10.48443/rmw1-me46") ||
      !identical(as.character(b$meta$release_generated),"2026-01-23") ||
      !identical(as.character(b$meta$schema_version),"mosquito-pulse-opportunity-v1")) note(paste(site,"wrong release identity"))
  if (!isTRUE(all.equal(as.numeric(b$meta$effort_days),sum(valid$effort_days)))) note(paste(site,"meta effort mismatch"))
  if (!identical(as.integer(b$meta$n_occ_attempted),as.integer(nrow(valid)))) note(paste(site,"meta opportunity mismatch"))
  if (!identical(as.integer(b$meta$n_zero_catch),as.integer(sum(valid$zero_catch)))) note(paste(site,"meta zero mismatch"))
  target <- ob[ob$is_target %in% TRUE,,drop=FALSE]
  species <- target[target$is_species %in% TRUE,,drop=FALSE]
  total_target <- sum(as.numeric(target$count),na.rm=TRUE)
  index_oracle[[site]] <- data.frame(site=site, collections=nrow(valid), effort_days=sum(valid$effort_days),
    zero_catches=sum(valid$zero_catch), individuals=round(total_target),
    taxa=length(unique(species$scientificName)),
    mos_per_24h=if (sum(valid$effort_days)>0) total_target/sum(valid$effort_days) else NA_real_)
  totals <- totals + c(nrow(ob)+nrow(er),nrow(er),nrow(valid),sum(valid$zero_catch),nrow(ob),nrow(b$held_identifications))
}

index <- tryCatch(readRDS("data/site_index.rds"), error=function(e)e)
index_required <- c("site","collections","effort_days","zero_catches","individuals","taxa","mos_per_24h")
if (inherits(index,"error") || !is.data.frame(index) || length(setdiff(index_required,names(index))) ||
    !identical(sort(as.character(index$site)),expected)) note("site_index roster or schema mismatch") else {
  if (length(index_oracle) != length(expected)) note("site_index oracle incomplete") else {
    oracle <- do.call(rbind,index_oracle); oracle <- oracle[order(oracle$site),,drop=FALSE]
    observed <- index[order(index$site),index_required,drop=FALSE]
    if (!identical(as.character(observed$site),as.character(oracle$site))) note("site_index order/identity mismatch")
    for (field in setdiff(index_required,"site"))
      if (!isTRUE(all.equal(as.numeric(observed[[field]]),as.numeric(oracle[[field]]),tolerance=1e-10)))
        note(paste("site_index derived mismatch",field))
  }
}
search <- tryCatch(readRDS("data/search_index.rds"), error=function(e)e)
if (inherits(search,"error") || !is.list(search) || !is.data.frame(search$sites) ||
    !identical(sort(as.character(search$sites$site)),expected) ||
    !identical(as.character(search$release %||% ""),"RELEASE-2026")) note("search_index roster or release mismatch")
receipt <- tryCatch(utils::read.csv("data/source-receipt.csv", stringsAsFactors=FALSE), error=function(e)e)
receipt_req <- c("product","release","doi","release_generated","site","trapping_rows","sorting_rows","identification_rows","raw_md5")
receipt_ok <- !inherits(receipt,"error") && is.data.frame(receipt) && !length(setdiff(receipt_req,names(receipt)))
if (receipt_ok) receipt_ok <- identical(sort(as.character(receipt$site)),expected) &&
  all(!is.na(receipt$release) & receipt$release == "RELEASE-2026") &&
  all(!is.na(receipt$product) & receipt$product == "DP1.10043.001") &&
  all(!is.na(receipt$doi) & receipt$doi == "10.48443/rmw1-me46") &&
  all(!is.na(receipt$release_generated) & receipt$release_generated == "2026-01-23") &&
  all(!is.na(receipt$raw_md5) & grepl("^[0-9a-f]{32}$",tolower(receipt$raw_md5))) &&
  all(is.finite(receipt$trapping_rows) & receipt$trapping_rows > 0)
if (!receipt_ok) note("source receipt is missing or not exact RELEASE-2026")
for (path in c("data/cross_site.rds","data/search_index.rds","data/site_climate.rds","data/site_month_clim.rds"))
  if (!file.exists(path)) note(paste("missing derived index",path))

manifest <- tryCatch(jsonlite::fromJSON("manifest.json",simplifyVector=FALSE), error=function(e)e)
if (inherits(manifest,"error")) note("manifest unreadable") else {
  mf <- manifest$files
  expected_files <- sort(unique(c("global.R","ui.R","server.R",
    list.files("R", pattern="[.]R$", full.names=TRUE),
    list.files("www", recursive=TRUE, full.names=TRUE),
    list.files("data", recursive=TRUE, full.names=TRUE),
    list.files("data-sample", recursive=TRUE, full.names=TRUE))))
  expected_files <- expected_files[file.exists(expected_files) & !dir.exists(expected_files)]
  if (!identical(sort(names(mf)), expected_files)) note(sprintf("manifest file set mismatch missing=[%s] extra=[%s]",
    paste(setdiff(expected_files,names(mf)),collapse=","), paste(setdiff(names(mf),expected_files),collapse=",")))
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
