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
  samplingImpractical = c(NA, "OK", NA, "logistical"),
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
expect(bundle$meta$n_valid_intervals == 3L, "missed sampling must not enter the valid intervals")
expect(bundle$meta$n_occ_attempted == 2L, "an interval with a pending or held catch must not enter the rate denominator")
expect(abs(bundle$meta$effort_days - 1) < 1e-9, "resolved effort is the 12h positive + 12h zero intervals = one 24-hour unit")
expect(abs(bundle$meta$valid_effort_days - 2) < 1e-9, "12h + 12h + 24h of sampled effort must equal two 24-hour units")
expect(abs(bundle$meta$unavailable_effort_days - 1) < 1e-9 && bundle$meta$n_unavailable_outcome == 1L,
       "the held interval's 24h must be disclosed as unavailable effort, not dropped silently")
expect(abs(sum(bundle$effort_week$effort_days) - 1) < 1e-9, "effort_week must carry resolved effort only")
expect(identical(bundle$meta$schema_version, "mosquito-pulse-opportunity-v2"), "resolved-effort bundles are schema v2")
expect(bundle$meta$n_zero_catch == 1L, "only targetTaxaPresent=N is a supported zero catch")
expect(bundle$meta$n_held_identifications == 1L, "invalid proportionIdentified must be held")
expect(abs(sum(bundle$obs$count) - 14) < 1e-9, "eligible identified counts must expand continuously by 1/p")
expect(sum(bundle$obs$is_species) == 1L, "genus-level rows must not pass the species gate")
expect(!mos_is_species("species", "Aedes vexans", "cf."),
       "qualified or uncertain identifications must remain in totals but not species richness")
expect(any(bundle$effort$outcome_status == "catch_unusable_or_pending"), "held catches must not be relabeled zero")
status_of <- function(uid) bundle$effort$effort_status[bundle$effort$source_uid == uid]
expect(identical(status_of("u-day"), "valid_sampled"),
       "samplingImpractical 'OK' (NEON User Guide Table 1: sampling occurred) must be valid effort")
expect(identical(status_of("u-missed"), "not_sampled"), "a documented impractical code must be not sampled")
expect(identical(mos_sampling_occurred(c(NA, "OK", " ok ", "other", "Temperature low", "Location snow covered")),
                 c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)),
       "the samplingImpractical map must accept NA and OK and reject every documented impractical code")
expect(tryCatch({ mos_sampling_occurred(c("OK", "Road closure")); FALSE }, error = function(e) TRUE),
       "an unknown samplingImpractical code must stop the producer")
expect(tryCatch({ mos_build_effort(dplyr::mutate(trapping, samplingImpractical = "sampled"), "TEST"); FALSE },
                error = function(e) TRUE),
       "an unknown samplingImpractical code must stop the bundle build, not drop effort")
shuffled <- mos_build_bundle(list(
  mos_trapping = trapping[c(4, 2, 1, 3), ],
  mos_sorting = sorting[2:1, ],
  mos_expertTaxonomistIDProcessed = ident[c(3, 1, 2), ]
), "TEST")
expect(identical(shuffled, bundle), "bundle rows must be in canonical order whatever order NEON returns")

qc_obs <- tibble::tibble(
  scientificName = "Culex tarsalis", sampleID = c("s1", "s2"), plotID = "TEST_001", trapID = "001",
  year = 2024L, collectDate = as.Date("2024-07-02"), sex = "F", count = c(3, 4), trapHours = 12,
  targetTaxaPresent = "Y", sampleCondition = "No known compromise", nightOrDay = "night",
  expansionFactor = 1, taxonRank = "species", is_target = TRUE,
  identificationQualifier = c(NA_character_, "cf. species"),
  is_species = mos_is_species("species", "Culex tarsalis", c(NA_character_, "cf. species"))
)
qc_uncertain <- function(d) {
  f <- Filter(function(x) identical(x$key, "uncertain"), mos_qc(d, "Culex tarsalis")$flags)
  if (length(f)) f[[1]]$n else 0L
}
expect(qc_uncertain(qc_obs) == 1L,
       "only the 'cf.' row may raise the uncertain-identification flag; an NA qualifier is certain")
expect(qc_uncertain(qc_obs[, setdiff(names(qc_obs), "is_species")]) == 1L,
       "the qualifier fallback must not treat NA as a qualifier (nzchar(NA) is TRUE)")

board <- vector_board(bundle$obs, bundle$meta$n_occ_attempted, bundle$meta$effort_days)
headline <- site_vectors(bundle$obs, bundle$meta$n_occ_attempted, bundle$meta$effort_days,
                         bundle$effort_week, bundle$meta$n_traps)
expect(nrow(board) == 1L, "species board must include species-level target taxa only")
expect(abs(headline$index - 14) < 1e-9, "headline total must retain genus-level target catch over resolved effort (14 / 1)")
expect(isTRUE(headline$coarse_share > 0.28 && headline$coarse_share < 0.29), "coarse-ID share must count the genus-level catch (4 of 14)")
expect(isTRUE(headline$top_share == 71), "the largest single record (10 of 14) must be reported as its share of the catch")
expect(abs(vector_board(bundle$obs, bundle$meta$n_occ_attempted, 0.5)$index[1] - 20) < 1e-9,
       "continuous sub-day effort must not be silently floored to one 24-hour unit")

acc <- mos_accum(bundle$obs, bundle$effort, perms = 8)
expect(nrow(acc) == 2L, "accumulation must include every resolved opportunity, including zero catch")

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

# pulse_peak: a one-year spike must not beat a multi-year median peak
pk <- data.frame(week = 20:23, index = c(5, 9, 50, 4), q25 = 0, q75 = 0, n_years = c(3L, 4L, 1L, 4L))
pp <- pulse_peak(pk)
expect(identical(pp$week, 21L) && identical(pp$n_years, 4L) && identical(pp$years_total, 4L),
       "the peak week needs at least half the trapped years behind it")
expect(identical(pulse_peak(data.frame(week = 30L, index = 2, q25 = 2, q75 = 2, n_years = 1L))$years_total, 1L),
       "a one-season site still gets a peak, flagged as one season")
bp <- pulse_phenology(bundle$obs, bundle$effort_week)
expect(all(bp$q25 <= bp$index & bp$index <= bp$q75) && all(bp$q25 >= 0), "the pulse band is the 25th to 75th percentile and never below zero")
cy <- catch_by_year(bundle$obs, "Aedes albopictus", bundle$effort_week, bundle$effort)
expect(nrow(cy) == 1L && abs(cy$index - 10) < 1e-9 && !cy$raw, "the yearly chart divides catch by that year's resolved effort")
cz <- catch_by_year(bundle$obs, "Culex pipiens", bundle$effort_week, bundle$effort)
expect(nrow(cz) == 1L && cz$mosquitoes == 0, "a year with effort and no catch of the species is a zero, not a gap")
ch <- chao2_collections(tibble::tibble(scientificName = c("a", "b", "c", "c"), occ_id = c("1", "2", "3", "4"),
  is_target = TRUE, is_species = TRUE), n_occ = 10)
expect(abs(ch$chao2 - (3 + 0.9 * 2 * 1 / (2 * 2))) < 0.051, "Chao2 point estimate uses the bias-corrected (Q2 + 1) form")

cat("OK: Mosquito opportunity, zero-catch, expansion, richness, and accumulation contracts passed.\n")
