#!/usr/bin/env Rscript
suppressWarnings(suppressMessages({
  library(dplyr)
  library(tibble)
}))
source("R/mos_bundle_contract.R")
source("R/mos_helpers.R")

fail <- function(message) stop("CONTRACT TEST FAILED: ", message, call. = FALSE)
expect <- function(condition, message) if (!isTRUE(condition)) fail(message)

trapping <- tibble::tibble(
  uid = c("u-night", "u-day", "u-held", "u-missed"),
  eventID = c("event-1", "event-1", "event-1", "event-2"),
  sampleID = c("sample-night", NA_character_, "sample-held", NA_character_),
  plotID = rep("TEST_001", 4),
  setDate = c("2024-07-01T18:00:00Z", "2024-07-02T06:00:00Z", "2024-07-03T18:00:00Z", "2024-07-04T18:00:00Z"),
  collectDate = c("2024-07-02T06:00:00Z", "2024-07-02T22:00:00Z", "2024-07-04T06:00:00Z", "2024-07-05T06:00:00Z"),
  trapHours = c(12, 12, 24, 12),
  nightOrDay = c("night", "day", "night", "night"),
  targetTaxaPresent = c("Y", "N", "Y", NA_character_),
  samplingImpractical = c(NA, NA, NA, "Road closure"),
  sampleCondition = "No known compromise",
  fanStatus = "OK", catchCupStatus = "OK", CO2Status = "OK",
  decimalLatitude = 32, decimalLongitude = -111, nlcdClass = "shrub"
)
sorting <- tibble::tibble(
  subsampleID = c("sub-night", "sub-held"),
  sampleID = c("sample-night", "sample-held"),
  proportionIdentified = c(0.5, 0)
)
ident <- tibble::tibble(
  subsampleID = c("sub-night", "sub-night", "sub-held"),
  plotID = "TEST_001", collectDate = as.Date("2024-07-02"),
  taxonID = c("AEDALB", "AEDSPP", "CULPIP"),
  scientificName = c("Aedes albopictus", "Aedes sp.", "Culex pipiens"),
  taxonRank = c("species", "genus", "species"),
  family = "Culicidae", genus = c("Aedes", "Aedes", "Culex"),
  sex = "F", individualCount = c(5, 2, 4),
  nativeStatusCode = NA_character_, identificationQualifier = NA_character_
)

bundle <- mos_build_bundle(list(
  mos_trapping = trapping,
  mos_sorting = sorting,
  mos_expertTaxonomistIDProcessed = ident
), "TEST")

expect(nrow(bundle$effort) == 4L, "all trapping records must survive into the effort table")
expect(length(unique(bundle$effort$effort_id)) == 4L, "day/night intervals must have distinct effort keys")
expect(bundle$meta$n_occ_attempted == 3L, "missed sampling must not enter the valid denominator")
expect(abs(bundle$meta$effort_days - 2) < 1e-9, "12h + 12h + 24h must equal two 24-hour effort units")
expect(bundle$meta$n_zero_catch == 1L, "only targetTaxaPresent=N is a supported zero catch")
expect(bundle$meta$n_held_identifications == 1L, "invalid proportionIdentified must be held")
expect(abs(sum(bundle$obs$count) - 14) < 1e-9, "eligible identified counts must expand continuously by 1/p")
expect(sum(bundle$obs$is_species) == 1L, "genus-level rows must not pass the species gate")
expect(!mos_is_species("species", "Aedes vexans", "cf."),
       "qualified or uncertain identifications must remain in totals but not species richness")
expect(any(bundle$effort$outcome_status == "catch_unusable_or_pending"), "held catches must not be relabeled zero")

board <- vector_board(bundle$obs, bundle$meta$n_occ_attempted, bundle$meta$effort_days)
headline <- site_vectors(bundle$obs, bundle$meta$n_occ_attempted, bundle$meta$effort_days,
                         bundle$effort_week, bundle$meta$n_traps)
expect(nrow(board) == 1L, "species board must include species-level target taxa only")
expect(abs(headline$index - 7) < 1e-9, "headline total must retain genus-level target catch (14 / 2)")
expect(abs(vector_board(bundle$obs, bundle$meta$n_occ_attempted, 0.5)$index[1] - 20) < 1e-9,
       "continuous sub-day effort must not be silently floored to one 24-hour unit")

acc <- mos_accum(bundle$obs, bundle$effort, perms = 8)
expect(nrow(acc) == 3L, "accumulation must include all valid opportunities, including zero catch")

fallback <- trapping[1:2, ]
fallback$uid <- NA_character_
fallback_effort <- mos_build_effort(fallback, "TEST")
expect(all(fallback_effort$valid_effort) && length(unique(fallback_effort$effort_id)) == 2L,
       "complete fallback identity must preserve separate day/night intervals")
incomplete <- fallback[1, ]
incomplete$nightOrDay <- NA_character_
expect(!mos_build_effort(incomplete, "TEST")$valid_effort,
       "an incomplete fallback identity must not enter the denominator")
conflicting_effort <- dplyr::bind_rows(trapping[1, ], dplyr::mutate(trapping[1, ], trapHours = 9))
expect(tryCatch({ mos_build_effort(conflicting_effort, "TEST"); FALSE }, error = function(e) TRUE),
       "conflicting rows under one effort uid must fail closed")

invalid_props <- tibble::tibble(
  subsampleID = paste0("invalid-", 1:4), sampleID = paste0("sample-", 1:4),
  proportionIdentified = c(NA_real_, -0.1, 0, 1.1))
expect(all(mos_normalize_sorting(invalid_props)$expansion_status == "held_invalid_proportion"),
       "missing, negative, zero, and greater-than-one expansion proportions must all be held")

zero_trapping <- trapping[1:2, ]
zero_trapping$targetTaxaPresent <- "N"
zero_trapping$sampleID <- NA_character_
empty_sorting <- tibble::tibble(subsampleID = character(), sampleID = character(), proportionIdentified = numeric())
empty_ident <- tibble::tibble(subsampleID = character(), scientificName = character(), taxonRank = character(),
                              sex = character(), individualCount = numeric())
zero_bundle <- mos_build_bundle(list(mos_trapping = zero_trapping, mos_sorting = empty_sorting,
                                     mos_expertTaxonomistIDProcessed = empty_ident), "ZERO")
expect(nrow(zero_bundle$obs) == 0L && zero_bundle$meta$n_zero_catch == 2L,
       "an all-zero site must remain an eligible opportunity-complete bundle")
zero_acc <- mos_accum(zero_bundle$obs, zero_bundle$effort, perms = 8)
expect(nrow(zero_acc) == 2L && all(zero_acc$richness == 0),
       "an all-zero site accumulation must retain sampled opportunities at richness zero")
zero_pulse <- pulse_phenology(zero_bundle$obs, zero_bundle$effort_week)
expect(nrow(zero_pulse) >= 1L && all(zero_pulse$index == 0),
       "an all-zero site pulse must show sampled weeks at zero rather than disappear")

bad_sort <- dplyr::bind_rows(sorting, tibble::tibble(
  subsampleID = "sub-night", sampleID = "sample-night", proportionIdentified = 0.25))
errored <- tryCatch({ mos_normalize_sorting(bad_sort); FALSE }, error = function(e) TRUE)
expect(errored, "conflicting duplicate subsample mappings must fail closed")

cat("OK: Mosquito opportunity, zero-catch, expansion, richness, and accumulation contracts passed.\n")
