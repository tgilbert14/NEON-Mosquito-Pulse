# Opportunity-complete bundle contract for NEON DP1.10043.001.
#
# A sampling opportunity is one physical CO2-trap interval. It exists before
# any mosquito is caught and is never reconstructed from identification rows.
# The interval key prefers NEON's row uid and otherwise preserves event, plot,
# set/collect timestamps, and day/night identity. This prevents the daytime and
# nighttime halves of a bout from collapsing onto one plot/date key.

`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a
mos_num <- function(x) suppressWarnings(as.numeric(x))
mos_chr <- function(x) {
  y <- trimws(as.character(x))
  y[is.na(x) | !nzchar(y)] <- NA_character_
  y
}
mos_col <- function(d, name, default = NA_character_) {
  if (name %in% names(d)) d[[name]] else rep(default, nrow(d))
}
mos_date <- function(x) as.Date(substr(as.character(x), 1L, 10L))
mos_timestamp <- function(x) {
  y <- mos_chr(x)
  y <- sub("[.]000Z$", "Z", y)
  y
}
mos_mode <- function(x) {
  x <- x[!is.na(x)]
  if (!length(x)) return(NA_character_)
  names(sort(table(x), decreasing = TRUE))[1L]
}

mos_require <- function(d, fields, table) {
  missing <- setdiff(fields, names(d))
  if (length(missing)) stop(table, " missing required fields: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

mos_is_species <- function(rank, scientific_name, qualifier = NULL) {
  rank <- tolower(mos_chr(rank))
  sci <- mos_chr(scientific_name)
  qual <- if (is.null(qualifier)) rep(NA_character_, length(sci)) else tolower(mos_chr(qualifier))
  accepted <- rank %in% c("species", "subspecies")
  ambiguous <- grepl("\\bsp[.]?$", ifelse(is.na(sci), "", sci), ignore.case = TRUE) |
    grepl("/", ifelse(is.na(sci), "", sci), fixed = TRUE)
  uncertain <- !is.na(qual) & !(qual %in% c("na", "none", "not applicable"))
  accepted & !ambiguous & !uncertain
}

mos_sampling_occurred <- function(x) {
  value <- tolower(mos_chr(x))
  is.na(value) | value %in% c("n", "no", "none", "not applicable", "sampling occurred")
}

mos_effort_key <- function(trapping) {
  uid <- mos_chr(mos_col(trapping, "uid"))
  event <- mos_chr(mos_col(trapping, "eventID"))
  plot <- mos_chr(mos_col(trapping, "plotID"))
  set_at <- mos_timestamp(mos_col(trapping, "setDate"))
  collect_at <- mos_timestamp(mos_col(trapping, "collectDate"))
  interval <- tolower(mos_chr(mos_col(trapping, "nightOrDay")))
  composite <- paste(ifelse(is.na(event), "no-event", event), plot,
                     ifelse(is.na(set_at), "no-set", set_at), collect_at,
                     ifelse(is.na(interval), "no-interval", interval), sep = "|")
  ifelse(!is.na(uid), paste0("uid:", uid), paste0("interval:", composite))
}

mos_normalize_sorting <- function(sorting) {
  mos_require(sorting, c("subsampleID", "sampleID", "proportionIdentified"), "mos_sorting")
  out <- data.frame(
    subsampleID = mos_chr(sorting$subsampleID),
    sampleID = mos_chr(sorting$sampleID),
    proportionIdentified = mos_num(sorting$proportionIdentified),
    stringsAsFactors = FALSE
  )
  out <- unique(out)
  key <- ifelse(is.na(out$subsampleID), "<NA>", out$subsampleID)
  conflict <- vapply(split(seq_len(nrow(out)), key), function(i) {
    length(unique(paste(out$sampleID[i], out$proportionIdentified[i], sep = "|"))) > 1L
  }, logical(1))
  if (any(conflict)) stop("mos_sorting has conflicting rows for subsampleID: ",
                          paste(names(conflict)[conflict], collapse = ", "), call. = FALSE)
  out <- out[!duplicated(key), , drop = FALSE]
  out$expansionFactor <- ifelse(is.finite(out$proportionIdentified) &
                                  out$proportionIdentified > 0 &
                                  out$proportionIdentified <= 1,
                                1 / out$proportionIdentified, NA_real_)
  out$expansion_status <- ifelse(is.finite(out$expansionFactor), "eligible", "held_invalid_proportion")
  out
}

mos_build_effort <- function(trapping, site) {
  mos_require(trapping, c("plotID", "collectDate", "trapHours", "nightOrDay", "targetTaxaPresent"), "mos_trapping")
  effort <- data.frame(
    effort_id = mos_effort_key(trapping),
    source_uid = mos_chr(mos_col(trapping, "uid")),
    eventID = mos_chr(mos_col(trapping, "eventID")),
    sampleID = mos_chr(mos_col(trapping, "sampleID")),
    site = site,
    plotID = mos_chr(trapping$plotID),
    trapID = sub("^[A-Z]{4}_", "", mos_chr(trapping$plotID)),
    setDate = mos_timestamp(mos_col(trapping, "setDate")),
    collectTimestamp = mos_timestamp(trapping$collectDate),
    collectDate = mos_date(trapping$collectDate),
    nightOrDay = tolower(mos_chr(trapping$nightOrDay)),
    trapHours = mos_num(trapping$trapHours),
    targetTaxaPresent = mos_chr(trapping$targetTaxaPresent),
    samplingImpractical = mos_chr(mos_col(trapping, "samplingImpractical")),
    sampleCondition = mos_chr(mos_col(trapping, "sampleCondition")),
    fanStatus = mos_chr(mos_col(trapping, "fanStatus")),
    catchCupStatus = mos_chr(mos_col(trapping, "catchCupStatus")),
    CO2Status = mos_chr(mos_col(trapping, "CO2Status", NA_character_)),
    dryIceStatus = mos_chr(mos_col(trapping, "dryIceStatus", NA_character_)),
    lat = mos_num(mos_col(trapping, "decimalLatitude", NA_real_)),
    lng = mos_num(mos_col(trapping, "decimalLongitude", NA_real_)),
    nlcdClass = mos_chr(mos_col(trapping, "nlcdClass")),
    stringsAsFactors = FALSE
  )
  fingerprint <- apply(effort, 1L, function(x) paste(ifelse(is.na(x), "<NA>", x), collapse = "\u241f"))
  exact <- !duplicated(fingerprint)
  effort <- effort[exact, , drop = FALSE]
  by_key <- split(seq_len(nrow(effort)), effort$effort_id)
  conflict <- vapply(by_key, length, integer(1)) > 1L
  if (any(conflict)) stop("mos_trapping has conflicting rows for effort_id: ",
                          paste(names(conflict)[conflict], collapse = ", "), call. = FALSE)
  sample_rows <- effort[!is.na(effort$sampleID), , drop = FALSE]
  if (anyDuplicated(sample_rows$sampleID)) stop("mos_trapping has duplicate non-missing sampleID values", call. = FALSE)

  occurred <- mos_sampling_occurred(effort$samplingImpractical)
  duration_ok <- is.finite(effort$trapHours) & effort$trapHours > 0
  identity_ok <- !is.na(effort$source_uid) |
    (!is.na(effort$eventID) & !is.na(effort$plotID) & !is.na(effort$setDate) &
       !is.na(effort$collectTimestamp) & !is.na(effort$nightOrDay))
  effort$valid_effort <- occurred & duration_ok & identity_ok
  effort$effort_status <- ifelse(!occurred, "not_sampled",
                          ifelse(!duration_ok, "unusable_duration",
                          ifelse(!identity_ok, "unusable_identity", "valid_sampled")))
  effort$effort_days <- ifelse(effort$valid_effort, effort$trapHours / 24, 0)
  effort$year <- as.integer(format(effort$collectDate, "%Y"))
  effort$week <- as.integer(format(effort$collectDate, "%U"))
  effort$protocol_era <- ifelse(effort$year < 2018L, "2013-2017: two nights + intervening day",
                                "2018-present: one night + following day")
  effort
}

mos_build_bundle <- function(raw, site, release = "RELEASE-2026") {
  required_tables <- c("mos_trapping", "mos_sorting", "mos_expertTaxonomistIDProcessed")
  missing_tables <- setdiff(required_tables, names(raw))
  if (length(missing_tables)) stop("raw object missing tables: ", paste(missing_tables, collapse = ", "), call. = FALSE)

  trapping <- tibble::as_tibble(raw$mos_trapping)
  sorting <- mos_normalize_sorting(tibble::as_tibble(raw$mos_sorting))
  ident <- tibble::as_tibble(raw$mos_expertTaxonomistIDProcessed)
  effort <- mos_build_effort(trapping, site)
  mos_require(ident, c("subsampleID", "scientificName", "taxonRank", "sex", "individualCount"),
              "mos_expertTaxonomistIDProcessed")
  # Identification tables can repeat plot/date context. The effort table is the
  # sole authority for sampling identity and duration, so discard overlapping
  # context before the eligible joins instead of accepting .x/.y ambiguity.
  ident <- ident[, setdiff(names(ident), c("sampleID", "effort_id", "plotID", "trapID",
    "collectDate", "year", "week", "nightOrDay", "trapHours", "targetTaxaPresent",
    "sampleCondition", "valid_effort", "effort_status")), drop = FALSE]

  sample_map <- effort[!is.na(effort$sampleID), c("sampleID", "effort_id", "plotID", "trapID",
    "collectDate", "year", "week", "nightOrDay", "trapHours", "targetTaxaPresent",
    "sampleCondition", "valid_effort", "effort_status"), drop = FALSE]
  joined <- dplyr::left_join(ident, sorting, by = "subsampleID")
  joined <- dplyr::left_join(joined, sample_map, by = "sampleID")
  joined$individualCount <- mos_num(joined$individualCount)
  joined$hold_reason <- ifelse(is.na(joined$sampleID), "held_unmatched_sorting",
                        ifelse(is.na(joined$effort_id), "held_unmatched_effort",
                        ifelse(joined$expansion_status != "eligible", "held_invalid_proportion",
                        ifelse(!joined$valid_effort, "held_invalid_effort",
                        ifelse(!is.finite(joined$individualCount) | joined$individualCount <= 0,
                               "held_nonpositive_count", NA_character_)))))
  held <- joined[!is.na(joined$hold_reason), c("subsampleID", "sampleID", "effort_id", "scientificName",
    "individualCount", "proportionIdentified", "expansionFactor", "hold_reason"), drop = FALSE]
  eligible <- joined[is.na(joined$hold_reason), , drop = FALSE]

  family <- mos_chr(mos_col(eligible, "family"))
  genus <- mos_chr(mos_col(eligible, "genus"))
  scientific <- mos_chr(eligible$scientificName)
  taxon_rank <- mos_chr(eligible$taxonRank)
  qualifier <- mos_chr(mos_col(eligible, "identificationQualifier"))
  obs <- data.frame(
    sampleID = mos_chr(eligible$sampleID),
    effort_id = mos_chr(eligible$effort_id),
    occ_id = mos_chr(eligible$effort_id),
    trapkey = mos_chr(eligible$plotID),
    plotID = mos_chr(eligible$plotID),
    trapID = mos_chr(eligible$trapID),
    year = as.integer(eligible$year),
    collectDate = mos_date(eligible$collectDate),
    week = as.integer(eligible$week),
    taxonID = mos_chr(mos_col(eligible, "taxonID")),
    scientificName = scientific,
    vernacularName = NA_character_,
    taxonRank = taxon_rank,
    is_species = mos_is_species(taxon_rank, scientific, qualifier),
    genus = ifelse(is.na(genus), sub(" .*", "", scientific), genus),
    sex = toupper(substr(mos_chr(eligible$sex), 1L, 1L)),
    nativeStatusCode = mos_chr(mos_col(eligible, "nativeStatusCode")),
    count = eligible$individualCount * eligible$expansionFactor,
    is_target = is.na(family) | family == "Culicidae",
    nightOrDay = mos_chr(eligible$nightOrDay),
    trapHours = mos_num(eligible$trapHours),
    targetTaxaPresent = mos_chr(eligible$targetTaxaPresent),
    sampleCondition = mos_chr(eligible$sampleCondition),
    proportionIdentified = mos_num(eligible$proportionIdentified),
    expansionFactor = mos_num(eligible$expansionFactor),
    identificationQualifier = qualifier,
    stringsAsFactors = FALSE
  )
  obs$sex[is.na(obs$sex) | !(obs$sex %in% c("F", "M"))] <- "U"
  obs <- obs[!is.na(obs$scientificName) & is.finite(obs$count) & obs$count > 0, , drop = FALSE]

  target_obs <- obs[obs$is_target %in% TRUE, , drop = FALSE]
  catch_by_effort <- if (nrow(target_obs)) stats::aggregate(count ~ effort_id, target_obs, sum) else data.frame()
  effort$target_count <- 0
  if (nrow(catch_by_effort)) effort$target_count[match(catch_by_effort$effort_id, effort$effort_id, nomatch = 0L)] <- catch_by_effort$count
  held_effort <- unique(mos_chr(held$effort_id))
  target_flag <- toupper(substr(effort$targetTaxaPresent, 1L, 1L))
  effort$outcome_status <- ifelse(!effort$valid_effort, "not_eligible",
    ifelse(effort$target_count > 0, "positive_catch",
    ifelse(target_flag %in% "N", "zero_catch",
    ifelse(effort$effort_id %in% held_effort | target_flag %in% "Y", "catch_unusable_or_pending", "outcome_unknown"))))
  effort$zero_catch <- effort$outcome_status == "zero_catch"
  effort$target_flag_conflict <- effort$target_count > 0 & toupper(substr(effort$targetTaxaPresent, 1L, 1L)) == "N"

  valid <- effort[effort$valid_effort, , drop = FALSE]
  effort_week <- valid |>
    dplyr::group_by(.data$year, .data$week) |>
    dplyr::summarise(effort_days = sum(.data$effort_days),
                     opportunities = dplyr::n(), zero_catches = sum(.data$zero_catch), .groups = "drop")
  traps <- valid |>
    dplyr::group_by(.data$plotID) |>
    dplyr::summarise(trapID = dplyr::first(.data$trapID), nlcdClass = mos_mode(.data$nlcdClass),
      lat = stats::median(.data$lat, na.rm = TRUE), lng = stats::median(.data$lng, na.rm = TRUE),
      collectDate = suppressWarnings(max(.data$collectDate, na.rm = TRUE)),
      effort_days = sum(.data$effort_days), trap_nights = sum(.data$effort_days),
      n_collections = dplyr::n(), zero_catches = sum(.data$zero_catch), .groups = "drop") |>
    dplyr::mutate(trapkey = .data$plotID)
  years <- sort(unique(valid$year[is.finite(valid$year)]))
  meta <- list(
    site = site,
    lat = stats::median(valid$lat, na.rm = TRUE),
    lng = stats::median(valid$lng, na.rm = TRUE),
    years = years,
    effort_days = sum(valid$effort_days),
    trap_nights = sum(valid$effort_days),
    n_occ_attempted = nrow(valid),
    n_zero_catch = sum(valid$zero_catch),
    n_invalid_effort = sum(!effort$valid_effort),
    n_held_identifications = nrow(held),
    n_traps = length(unique(valid$plotID)),
    release = release,
    product = "DP1.10043.001",
    doi = "10.48443/rmw1-me46",
    release_generated = "2026-01-23",
    schema_version = "mosquito-pulse-opportunity-v1",
    metric_label = "mosquitoes per 24 trap-hours"
  )
  list(obs = tibble::as_tibble(obs), effort = tibble::as_tibble(effort),
       traps = tibble::as_tibble(traps), effort_week = tibble::as_tibble(effort_week),
       held_identifications = tibble::as_tibble(held), meta = meta)
}
