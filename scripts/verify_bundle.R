#!/usr/bin/env Rscript
# Fail-closed verification of opportunity-complete bundles and deploy bytes.
suppressMessages(library(jsonlite))
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a
source("R/mos_release.R")
source("R/site_metadata.R")
problems <- character(0)
note <- function(x) problems[[length(problems)+1L]] <<- x
expected <- sort(unique(as.character(neon_sites$site)))
files <- sort(list.files("data/sites", pattern="[.]rds$", full.names=TRUE))
sites <- sub("[.]rds$", "", basename(files))
if (!identical(sites, expected)) note(sprintf("site roster mismatch missing=[%s] extra=[%s]",
  paste(setdiff(expected, sites), collapse=","), paste(setdiff(sites, expected), collapse=",")))

# samplingImpractical vocabulary, written out here on purpose rather than read
# from R/mos_bundle_contract.R, so the validator does not grade the producer's
# rule with that same rule. NEON User Guide vH Table 1: OK = sampling occurred.
sampled_codes <- c("ok")
impractical_codes <- c("location snow covered","location flooded","temperature low",
                       "logistical","management","extreme weather","other")
# Coverage lag gate (months) against NEON's availableMonths for the release.
# Measured at the first rebuild: raw effort reaches the last available month at
# all 47 sites and the last valid interval trails it by 0 to 2 months (winter
# off-season records). A truncated fetch or a dropped code moves these by years.
max_raw_lag <- 1L
max_valid_lag <- as.integer(Sys.getenv("MOS_MAX_COVERAGE_LAG_MONTHS", "6"))
month_index <- function(x) { x <- as.character(x); as.integer(substr(x,1,4))*12L + as.integer(substr(x,6,7)) }
warnings_out <- character(0)
warn <- function(x) warnings_out[[length(warnings_out)+1L]] <<- x
receipt <- tryCatch(utils::read.csv("data/source-receipt.csv", stringsAsFactors=FALSE), error=function(e)e)
coverage <- if (!inherits(receipt,"error") && all(c("site","available_last_month") %in% names(receipt)))
  setNames(as.character(receipt$available_last_month), receipt$site) else character(0)

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
  if (!identical(as.character(b$meta$release),MOS_RELEASE$release) ||
      !identical(as.character(b$meta$product),MOS_RELEASE$product) ||
      !identical(as.character(b$meta$doi),MOS_RELEASE$doi) ||
      !identical(as.character(b$meta$release_generated),MOS_RELEASE$release_generated) ||
      !identical(as.character(b$meta$schema_version),"mosquito-pulse-opportunity-v2")) note(paste(site,"wrong release identity"))
  code <- if ("samplingImpractical" %in% names(er)) tolower(trimws(as.character(er$samplingImpractical))) else rep(NA_character_, nrow(er))
  code[!is.na(code) & !nzchar(code)] <- NA_character_
  unknown <- sort(unique(code[!is.na(code) & !(code %in% c(sampled_codes, impractical_codes))]))
  if (length(unknown)) note(paste(site,"unknown samplingImpractical code(s):",paste(unknown,collapse=",")))
  occurred <- is.na(code) | code %in% sampled_codes
  if (any(occurred & er$effort_status == "not_sampled")) note(sprintf("%s %d interval(s) coded NA/OK (sampling occurred) are classed not_sampled",
    site, sum(occurred & er$effort_status == "not_sampled")))
  if (any(code %in% impractical_codes & er$effort_status != "not_sampled")) note(paste(site,"impractical interval classed as sampled"))
  if (!identical(as.integer(sort(unique(b$meta$years))), as.integer(sort(unique(valid$year[is.finite(valid$year)])))))
    note(paste(site,"meta years differ from the years with valid intervals"))
  if (!(site %in% names(coverage)) || is.na(coverage[[site]]) || !grepl("^[0-9]{4}-[0-9]{2}$", coverage[[site]])) {
    note(paste(site,"source receipt has no NEON availableMonths coverage"))
  } else {
    last_raw <- suppressWarnings(max(er$collectDate, na.rm=TRUE))
    last_valid <- suppressWarnings(max(valid$collectDate, na.rm=TRUE))
    raw_lag <- month_index(coverage[[site]]) - month_index(format(last_raw, "%Y-%m"))
    valid_lag <- month_index(coverage[[site]]) - month_index(format(last_valid, "%Y-%m"))
    if (!is.finite(raw_lag) || raw_lag > max_raw_lag) note(sprintf("%s raw effort ends %s but NEON lists data through %s",
      site, format(last_raw, "%Y-%m"), coverage[[site]]))
    if (!is.finite(valid_lag) || valid_lag > max_valid_lag) note(sprintf("%s valid intervals end %s, %s months before NEON's last available month %s",
      site, format(last_valid, "%Y-%m"), valid_lag, coverage[[site]]))
  }
  held_effort <- sum(b$held_identifications$hold_reason %in% "held_invalid_effort")
  ids <- nrow(ob) + nrow(b$held_identifications)
  if (ids > 0 && held_effort / ids > 0.01) warn(sprintf("%s %.1f%% of identifications are held for invalid effort (%d of %d)",
    site, 100 * held_effort / ids, held_effort, ids))
  # Resolved-effort oracle, rebuilt from the catch rows and NEON's own
  # targetTaxaPresent flag rather than from outcome_status: an interval enters a
  # rate denominator only if it has target catch or NEON recorded no target taxa.
  target <- ob[ob$is_target %in% TRUE,,drop=FALSE]
  species <- target[target$is_species %in% TRUE,,drop=FALSE]
  caught_ids <- unique(as.character(target$effort_id))
  flag_n <- toupper(substr(as.character(valid$targetTaxaPresent),1,1)) %in% "N"
  resolved_oracle <- (valid$effort_id %in% caught_ids) | (flag_n & !(valid$effort_id %in% caught_ids))
  if (!("denominator_ok" %in% names(er)) || !identical(as.logical(valid$denominator_ok), resolved_oracle))
    note(paste(site,"resolved-effort flag differs from the catch/targetTaxaPresent oracle"))
  if ("denominator_ok" %in% names(er) && any(er$denominator_ok & !er$valid_effort, na.rm=TRUE)) note(paste(site,"resolved effort outside valid effort"))
  rs <- valid[resolved_oracle,,drop=FALSE]
  resolved_days <- sum(rs$effort_days)
  if (!isTRUE(all.equal(as.numeric(b$meta$effort_days),resolved_days))) note(paste(site,"meta effort mismatch"))
  if (!identical(as.integer(b$meta$n_occ_attempted),as.integer(nrow(rs)))) note(paste(site,"meta opportunity mismatch"))
  if (!identical(as.integer(b$meta$n_valid_intervals %||% -1L),as.integer(nrow(valid)))) note(paste(site,"meta valid-interval count mismatch"))
  if (!isTRUE(all.equal(as.numeric(b$meta$unavailable_effort_days %||% NA),sum(valid$effort_days)-resolved_days))) note(paste(site,"meta unavailable effort mismatch"))
  if (!identical(as.integer(b$meta$n_zero_catch),as.integer(sum(valid$zero_catch)))) note(paste(site,"meta zero mismatch"))
  ew <- b$effort_week
  if (!isTRUE(all.equal(sum(as.numeric(ew$effort_days)),resolved_days))) note(paste(site,"effort_week does not sum to resolved effort"))
  wk_oracle <- tapply(rs$effort_days, paste(rs$year, rs$week), sum)
  wk_bundle <- setNames(as.numeric(ew$effort_days), paste(ew$year, ew$week))[names(wk_oracle)]
  if (length(wk_oracle) && !isTRUE(all.equal(as.numeric(wk_bundle), as.numeric(wk_oracle)))) note(paste(site,"effort_week differs from the per-week resolved-effort oracle"))
  total_target <- sum(as.numeric(target$count),na.rm=TRUE)
  index_oracle[[site]] <- data.frame(site=site, collections=nrow(rs), effort_days=resolved_days,
    zero_catches=sum(valid$zero_catch), individuals=round(total_target),
    taxa=length(unique(species$scientificName)),
    mos_per_24h=if (resolved_days>0) total_target/resolved_days else NA_real_)
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
    !identical(as.character(search$release %||% ""),MOS_RELEASE$release)) note("search_index roster or release mismatch")
receipt_req <- c("product","release","doi","release_generated","site","trapping_rows","sorting_rows","identification_rows","raw_md5",
                 "available_first_month","available_last_month","available_month_count")
receipt_ok <- !inherits(receipt,"error") && is.data.frame(receipt) && !length(setdiff(receipt_req,names(receipt)))
if (receipt_ok) receipt_ok <- identical(sort(as.character(receipt$site)),expected) &&
  all(!is.na(receipt$release) & receipt$release == MOS_RELEASE$release) &&
  all(!is.na(receipt$product) & receipt$product == MOS_RELEASE$product) &&
  all(!is.na(receipt$doi) & receipt$doi == MOS_RELEASE$doi) &&
  all(!is.na(receipt$release_generated) & receipt$release_generated == MOS_RELEASE$release_generated) &&
  all(!is.na(receipt$raw_md5) & grepl("^[0-9a-f]{32}$",tolower(receipt$raw_md5))) &&
  all(is.finite(receipt$trapping_rows) & receipt$trapping_rows > 0)
if (!receipt_ok) note(paste("source receipt is missing or not exact", MOS_RELEASE$release))
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
for (w in unique(warnings_out)) cat(sprintf("::warning title=Mosquito verification::%s\n",w))
if (length(problems)) {
  for (problem in unique(problems)) cat(sprintf("::error title=Mosquito verification::%s\n",problem))
  stop(sprintf("Mosquito verification FAILED with %d problem(s)",length(unique(problems))),call.=FALSE)
}
cat("OK: Mosquito release, opportunities, zeros, indexes, and manifest passed.\n")
