# ===========================================================================
# NEON Mosquito Pulse — mos_helpers.R
# CO2-trap mosquito analyses on DP1.10043.001. The honesty backbone: a CO2
# trap lures HOST-SEEKING FEMALES, and big catches are subsampled then weight-
# expanded, so the abundance axis is an ACTIVITY INDEX (mosquitoes per
# 24 trap-hours), never a population. Each daytime or nighttime trap interval is
# one sampling opportunity; trapHours/24 is the effort denominator. sampleID is
# an outcome linkage and may be missing on zero-catch opportunities, so incidence
# uses the opportunity key (effort_id/occ_id), never catch rows alone.
# ===========================================================================
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
mode_chr <- function(x){ x<-x[!is.na(x)]; if(!length(x)) return(NA_character_); names(sort(table(x),decreasing=TRUE))[1] }
short_point <- function(p) sub("^[A-Z]{4}_", "", as.character(p))

# species-level, target-mosquito gate. genus-only "Culex sp." and damaged IDs
# are excluded from richness/composition (they inflate the singleton term) but a
# Culex sp. is still a host-seeking female, so it stays in the TOTAL activity index.
species_level_only <- function(d){
  if (is.null(d) || !nrow(d)) return(d)
  if ("is_species" %in% names(d)) return(d[d$is_species %in% TRUE, , drop = FALSE])
  ok <- is.na(d$taxonRank) | d$taxonRank %in% c("species","subspecies")
  d[ok, , drop = FALSE]
}
target_only <- function(d){ if (is.null(d) || !nrow(d)) return(d); if ("is_target" %in% names(d)) d[d$is_target %in% TRUE, , drop = FALSE] else d }
num <- function(x) suppressWarnings(as.numeric(x))

# ---------------------------------------------------------------------------
# vector_board(): one row per mosquito species — the Swarm Board.
#   index    = whole-trap-scaled count / effort in 24-hour units
#   ubiquity = % of ATTEMPTED collection occasions where ever caught (a steadier,
#              less catch-biased axis than the index, though still detection-bound)
#   female_share = % of sexed individuals that were female (a TRAP signature)
# n_occ = total collection occasions ATTEMPTED at the site (from the effort/trapping
# table, INCLUDING zero-catch nights), NOT n_distinct over the catch-only obs — else
# ubiquity inflates (the suite's "join LEFT, keep the zeros" honesty rule).
# ---------------------------------------------------------------------------
vector_board <- function(obs, n_occ = NULL, trap_nights = NULL) {
  sp <- target_only(species_level_only(obs)); if (is.null(sp) || !nrow(sp)) return(NULL)
  sp$.occ <- collection_occasion(sp)   # the sampled interval occasion (occ_id), not sampleID
  tn <- num(trap_nights %||% NA_real_)[1]
  if (!is.finite(tn) || tn <= 0) tn <- max(1, dplyr::n_distinct(sp$.occ))
  n_occ <- max(1L, as.integer(n_occ %||% dplyr::n_distinct(collection_occasion(obs))))
  sp$.cnt <- num(sp$count)
  sp %>% dplyr::group_by(.data$scientificName) %>%
    dplyr::summarise(
      vernacular = mode_chr(.data$vernacularName),
      genus = mode_chr(.data$genus),
      detections = dplyr::n(),
      total = sum(.data$.cnt, na.rm = TRUE),
      n_occ_present = dplyr::n_distinct(.data$.occ),
      n_traps = dplyr::n_distinct(.data$trapkey),
      female = sum(.data$.cnt[toupper(substr(.data$sex,1,1)) == "F"], na.rm = TRUE),
      male   = sum(.data$.cnt[toupper(substr(.data$sex,1,1)) == "M"], na.rm = TRUE),
      .groups = "drop") %>%
    dplyr::mutate(
      index = round(.data$total / tn, 3),
      ubiquity = round(100 * .data$n_occ_present / n_occ, 1),
      female_share = ifelse(.data$female + .data$male > 0, round(100 * .data$female / (.data$female + .data$male)), NA_real_),
      genus = .data$genus %||% sub(" .*", "", .data$scientificName),
      # NEON mosquito data carries no common names, so the scientific name IS the
      # display name. Fall back to it (NA-safe, unlike %||%) so nothing shows "NA".
      vernacular = ifelse(is.na(.data$vernacular) | !nzchar(.data$vernacular), .data$scientificName, .data$vernacular)) %>%
    dplyr::arrange(dplyr::desc(.data$index))
}

# site headline (hero stats). index = site activity index (per 24 trap-hours).
site_vectors <- function(obs, n_occ = NULL, trap_nights = NULL, effort_week = NULL, n_traps = NA) {
  brd <- vector_board(obs, n_occ, trap_nights)
  tn <- num(trap_nights %||% NA_real_)[1]
  if (!is.finite(tn) || tn <= 0) tn <- max(1, if (nrow(obs)) dplyr::n_distinct(collection_occasion(obs)) else 0)
  all_target <- target_only(obs); all_target$.cnt <- num(all_target$count)
  fem <- if (nrow(all_target)) sum(all_target$.cnt[toupper(substr(all_target$sex, 1, 1)) == "F"], na.rm = TRUE) else 0
  mal <- if (nrow(all_target)) sum(all_target$.cnt[toupper(substr(all_target$sex, 1, 1)) == "M"], na.rm = TRUE) else 0
  culex <- if (nrow(all_target)) sum(all_target$.cnt[all_target$genus == "Culex"], na.rm = TRUE) else 0
  tot <- sum(all_target$.cnt, na.rm = TRUE)
  # One collection can dominate a site's whole-trap total when a small sorted
  # subsample is expanded by 1/proportionIdentified; report its share so the
  # hero can say so.
  top_i <- if (nrow(all_target) && any(is.finite(all_target$.cnt))) which.max(all_target$.cnt) else integer(0)
  top_cnt <- if (length(top_i)) all_target$.cnt[top_i] else 0
  sp_tot <- { s <- species_level_only(all_target); if (is.null(s) || !nrow(s)) 0 else sum(s$.cnt, na.rm = TRUE) }
  pk <- pulse_phenology(obs, effort_week); peak <- pulse_peak(pk, obs)
  list(n_taxa = if (is.null(brd)) 0L else nrow(brd), index = round(tot / tn, 2),
       top_share = if (tot > 0) round(100 * top_cnt / tot) else NA_real_,
       index_excl_top = round((tot - top_cnt) / tn, 2),
       top_sample = if (length(top_i)) as.character(all_target$sampleID[top_i]) else NA_character_,
       top_date = if (length(top_i) && "collectDate" %in% names(all_target)) as.Date(all_target$collectDate[top_i]) else as.Date(NA),
       top_taxon = if (length(top_i)) as.character(all_target$scientificName[top_i]) else NA_character_,
       coarse_share = if (tot > 0) 1 - sp_tot / tot else NA_real_,
       pct_female = if (fem + mal > 0) round(100 * fem / (fem + mal)) else NA_real_,
       culex_share = if (tot > 0) round(100 * culex / tot) else NA_real_,
       peak_week = peak$week, peak_n_years = peak$n_years, peak_years_total = peak$years_total,
       peak_month = peak$month_label, n_traps = n_traps,
       effort_days = round(tn, 2), n_collections = as.integer(n_occ %||% dplyr::n_distinct(obs$sampleID)),
       top = if (is.null(brd)) "No mosquitoes detected" else brd$vernacular[which.max(brd$index)] %||% brd$scientificName[which.max(brd$index)])
}

# ---------------------------------------------------------------------------
# The MONSOON PULSE — activity index by week-of-year, averaged across years.
# Per (year, week): whole-trap catch / TRAP-NIGHTS of effort that week (from the
# effort_week table, which counts ALL attempted trap deployments INCLUDING
# zero-catch nights). Dividing by effort, not by caught-occasion count, keeps the
# shoulder-week zeros honest so the monsoon contrast isn't flattened (the suite's
# "keep the zeros" rule; matches the hero 24-hour-effort denominator). Weeks with
# no trapping at all are absent (a gap), never a zero. The app's signature chart.
# ---------------------------------------------------------------------------
week_of <- function(d) as.integer(format(as.Date(substr(as.character(d), 1, 10)), "%U"))
pulse_phenology <- function(obs, effort_week = NULL, era = NULL) {
  sp <- target_only(obs)
  catch <- data.frame(year = integer(0), week = integer(0), total = numeric(0), n_occ = integer(0))
  if (!is.null(sp) && nrow(sp)) {
    if (!"week" %in% names(sp)) sp$week <- week_of(sp$collectDate)
    sp$.cnt <- num(sp$count); sp$.occ <- collection_occasion(sp); sp <- sp[is.finite(sp$week), , drop = FALSE]
    if (nrow(sp)) catch <- sp %>% dplyr::group_by(.data$year, .data$week) %>%
      dplyr::summarise(total = sum(.data$.cnt, na.rm = TRUE), n_occ = dplyr::n_distinct(.data$.occ), .groups = "drop")
  }
  effort_col <- if (!is.null(effort_week) && "effort_days" %in% names(effort_week)) "effort_days" else "trap_nights"
  if (!is.null(effort_week) && nrow(effort_week) && effort_col %in% names(effort_week)) {
    ew <- effort_week; ew$.eff <- num(ew[[effort_col]]); ew <- ew[is.finite(ew$.eff) & ew$.eff > 0, , drop = FALSE]
    yw <- dplyr::left_join(ew[, c("year", "week", ".eff")], catch[, c("year", "week", "total")], by = c("year", "week"))
    yw$total[is.na(yw$total)] <- 0           # an attempted week with no catch is a real 0, not a gap
    yw$idx <- yw$total / yw$.eff             # mosquitoes per 24 trap-hours of effort that week
  } else if (nrow(catch)) {                  # compatibility fallback when no effort table is available
    yw <- catch; yw$idx <- yw$total / pmax(1L, yw$n_occ)
  } else return(NULL)
  # Across years per week: the MEDIAN, not the mean. Mosquito catch is wildly
  # skewed and outlier-prone (one fluke year can be 1000x a normal week), so a
  # mean lets a single freak January collection masquerade as the seasonal peak.
  # The median gives the typical year's pulse (standard in mosquito surveillance);
  # the band is the inter-quartile spread, so noisy weeks read as noisy.
  # The band is the 25th to 75th percentile across years, so it never dips
  # below zero and it is the "middle 50% of years" the chart says it is.
  if (!is.null(era)) yw <- yw[yw$year %in% era, , drop = FALSE]
  if (!nrow(yw)) return(NULL)
  yw %>% dplyr::group_by(.data$week) %>%
    dplyr::summarise(index = stats::median(.data$idx),
                     q25 = stats::quantile(.data$idx, 0.25, names = FALSE),
                     q75 = stats::quantile(.data$idx, 0.75, names = FALSE),
                     n_years = dplyr::n(), .groups = "drop") %>%
    dplyr::arrange(.data$week)
}

# The seasonal peak, gated on how many years support each week: a week trapped
# in one year keeps its raw single-year value while multi-year weeks are pulled
# to the median, so an ungated which.max lets one spike win. Require at least
# half the trapped years (minimum 2) before a week can be the peak.
pulse_peak <- function(pk, obs = NULL) {
  none <- list(week = NA_integer_, n_years = NA_integer_, years_total = NA_integer_, month_label = NA_character_)
  if (is.null(pk) || !nrow(pk) || !any(pk$index > 0, na.rm = TRUE)) return(none)
  Y <- max(pk$n_years)
  need <- if (Y >= 2) max(2L, ceiling(Y / 2)) else 1L
  ok <- pk[pk$n_years >= need & pk$index > 0, , drop = FALSE]
  if (!nrow(ok)) ok <- pk[pk$index > 0, , drop = FALSE]
  i <- which.max(ok$index); w <- ok$week[i]
  month <- NA_character_
  if (!is.null(obs) && nrow(obs) && all(c("week", "collectDate") %in% names(obs))) {
    d <- as.Date(obs$collectDate[obs$week %in% w])
    if (length(d) && any(!is.na(d))) month <- month.name[as.integer(format(stats::median(d, na.rm = TRUE), "%m"))]
  }
  if (is.na(month)) month <- month.name[as.integer(format(as.Date("2021-01-03") + 7 * max(0L, w), "%m"))]
  list(week = as.integer(w), n_years = as.integer(ok$n_years[i]), years_total = as.integer(Y), month_label = month)
}

# genus composition (shares of whole-trap catch)
genus_share <- function(obs) {
  sp <- target_only(obs); if (is.null(sp) || !nrow(sp)) return(NULL)
  sp$.cnt <- num(sp$count); sp$genus <- sp$genus %||% sub(" .*", "", sp$scientificName)
  g <- sp %>% dplyr::group_by(.data$genus) %>% dplyr::summarise(total = sum(.data$.cnt, na.rm = TRUE), .groups = "drop")
  g$share <- round(100 * g$total / sum(g$total), 1); g[order(-g$total), ]
}
# sex split for one species (or the whole site if sci = NULL)
sex_split <- function(obs, sci = NULL) {
  d <- target_only(obs); if (!is.null(sci)) d <- d[d$scientificName == sci & !is.na(d$scientificName), , drop = FALSE]
  if (is.null(d) || !nrow(d)) return(NULL)
  d$.cnt <- num(d$count); d$sx <- toupper(substr(d$sex, 1, 1)); d$sx[!(d$sx %in% c("F","M"))] <- "U"
  s <- tapply(d$.cnt, factor(d$sx, levels = c("F","M","U")), sum, na.rm = TRUE); s[is.na(s)] <- 0
  data.frame(sex = c("F","M","U"), count = as.numeric(s[c("F","M","U")]), stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# Incidence richness on valid collection opportunities (effort_id/occ_id),
# including supported zero catches. sampleID is never the primary denominator.
# Chao2 (Chao 1987; Colwell et al. 2012). Genus-only IDs excluded from richness.
# ---------------------------------------------------------------------------
# The sampling occasion is one physical daytime or nighttime trap interval. The
# bundler supplies the exact effort key and retains supported zero catches; old
# bundles fall back to sampleID only for compatibility.
collection_occasion <- function(sp) if ("occ_id" %in% names(sp)) as.character(sp$occ_id) else as.character(sp$sampleID)
# n_occ = total ATTEMPTED collection occasions (incl. zero-catch); the honest T for
# incidence Chao2. Falls back to caught-occasion count if not supplied.
chao2_collections <- function(obs, n_occ = NULL) {
  sp <- target_only(species_level_only(obs)); if (is.null(sp) || !nrow(sp)) return(NULL)
  occ <- collection_occasion(sp); m <- max(length(unique(occ)), as.integer(n_occ %||% length(unique(occ))))
  inc <- tapply(occ, sp$scientificName, function(o) length(unique(o)))
  inc <- as.numeric(inc); S <- length(inc); Q1 <- sum(inc == 1); Q2 <- sum(inc == 2)
  if (S == 0 || m < 2) return(NULL)
  corr <- (m - 1) / m
  # Bias-corrected Chao2 for every Q2, matching the (Q2 + 1) variance below.
  chao <- S + corr * Q1 * (Q1 - 1) / (2 * (Q2 + 1))
  f0 <- max(0, chao - S)
  var_f0 <- if (Q2 > 0)
    corr * (Q1 * (Q1 - 1)) / (2 * (Q2 + 1)) + corr^2 * (Q1 * (2 * Q1 - 1)^2) / (4 * (Q2 + 1)^2) +
      corr^2 * (Q1^2 * Q2 * (Q1 - 1)^2) / (4 * (Q2 + 1)^4)
  else corr * (Q1 * (Q1 - 1)) / 2 + corr^2 * (Q1 * (2 * Q1 - 1)^2) / 4 - corr^2 * (Q1^4) / (4 * chao)
  var_f0 <- max(var_f0, 0); ci_lo <- ci_hi <- NA_real_
  if (f0 > 0 && var_f0 > 0) { K <- exp(1.96 * sqrt(log(1 + var_f0 / f0^2))); ci_lo <- S + f0 / K; ci_hi <- S + f0 * K }
  else if (f0 == 0) { ci_lo <- ci_hi <- S }
  list(S_obs = S, chao2 = round(chao, 1), m = m, Q1 = Q1, Q2 = Q2, unstable = Q2 < 3,
       ci_lo = round(ci_lo, 1), ci_hi = round(ci_hi, 1))
}
# species accumulation over collection occasions (deterministic permutation mean).
# Vectorized O(perms*n): per permutation, each species' first-occurrence rank =
# min position over its occasions, then the richness curve = cumsum of how many
# species are first seen at each position. (The old growing-vector union loop was
# O(perms*k^2) — ~6s on the biggest real sites; this is ~60-86x faster.)
mos_accum <- function(obs, effort = NULL, perms = 40) {
  effort_ids <- if (!is.null(effort) && "effort_id" %in% names(effort)) {
    valid <- if ("denominator_ok" %in% names(effort)) effort$denominator_ok %in% TRUE else
      if ("valid_effort" %in% names(effort)) effort$valid_effort %in% TRUE else rep(TRUE, nrow(effort))
    as.character(effort$effort_id[valid])
  } else character(0)
  sp <- target_only(species_level_only(obs))
  if (is.null(sp) || !nrow(sp)) {
    k <- length(unique(effort_ids))
    return(if (k < 2) NULL else data.frame(occasions = seq_len(k), richness = rep(0, k)))
  }
  caught_ids <- collection_occasion(sp)
  levels <- unique(c(effort_ids, caught_ids))
  occ_id <- match(caught_ids, levels); k <- length(levels); if (k < 2) return(NULL)
  spv <- sp$scientificName
  acc <- numeric(k)
  for (s in 1:perms) {
    ord <- order((seq_len(k) * 7919L + s * 104729L) %% k)   # deterministic random-ish occasion order
    rank_of <- integer(k); rank_of[ord] <- seq_len(k)        # occasion -> its position in this order
    first <- tapply(rank_of[occ_id], spv, min)               # each species' first-appearance position
    acc <- acc + cumsum(tabulate(as.integer(first), nbins = k))
  }
  data.frame(occasions = seq_len(k), richness = round(acc / perms, 1))
}

# cross-site effort standardization (dependency-light; reused by build_cross_site.R)
site_incidence <- function(obs, n_occ = NULL) {
  sp <- target_only(species_level_only(obs)); if (is.null(sp) || !nrow(sp)) return(NULL)
  occ <- collection_occasion(sp)
  Y <- tapply(occ, sp$scientificName, function(o) length(unique(o)))
  list(Y = as.integer(Y), T = max(length(unique(occ)), as.integer(n_occ %||% length(unique(occ)))))
}
rarefy_incidence <- function(Y, T, t) {
  if (is.na(t) || t < 1 || t > T) return(NA_real_)
  contrib <- ifelse(T - Y < t, 1, 1 - exp(lchoose(T - Y, t) - lchoose(T, t)))
  round(sum(contrib), 1)
}
coverage_incidence <- function(Y, T) {
  U <- sum(Y); if (U == 0 || T < 2) return(NA_real_)
  Q1 <- sum(Y == 1); Q2 <- sum(Y == 2)
  1 - (Q1 / U) * ((T - 1) * Q1 / ((T - 1) * Q1 + 2 * max(Q2, 1)))
}
site_coverage <- function(obs, n_occ = NULL) { si <- site_incidence(obs, n_occ); if (is.null(si)) return(NA_real_); coverage_incidence(si$Y, si$T) }
hill_incidence <- function(Y) { p <- Y / sum(Y); p <- p[p > 0]
  c(q1 = round(exp(-sum(p * log(p))), 1), q2 = round(1 / sum(p^2), 1)) }

# per-species detail + by-year curve (for the Taxon Profile)
species_detail <- function(obs, sci) {
  d <- obs[obs$scientificName == sci & !is.na(obs$scientificName), , drop = FALSE]
  if (!nrow(d)) return(NULL); d
}
# Catch per 24 trap-hours by year for one species: every year with effort is
# kept (a year the species was not caught is a 0, not a gap), the denominator is
# that year's resolved effort, and years trapped for under half the usual number
# of weeks are marked partial. Without an effort table it falls back to the raw
# sum and says so (raw = TRUE).
catch_by_year <- function(obs, sci, effort_week = NULL, effort = NULL) {
  d <- species_detail(obs, sci)
  caught <- if (is.null(d)) data.frame(year = integer(0), mosquitoes = numeric(0)) else {
    d$.cnt <- num(d$count)
    d %>% dplyr::group_by(.data$year) %>% dplyr::summarise(mosquitoes = sum(.data$.cnt, na.rm = TRUE), .groups = "drop")
  }
  if (is.null(effort_week) || !nrow(effort_week) || !"effort_days" %in% names(effort_week)) {
    if (!nrow(caught)) return(NULL)
    caught$mosquitoes <- round(caught$mosquitoes); caught$raw <- TRUE; return(caught)
  }
  ew <- effort_week[is.finite(num(effort_week$effort_days)) & num(effort_week$effort_days) > 0, , drop = FALSE]
  if (!nrow(ew)) return(NULL)
  yr <- ew %>% dplyr::group_by(.data$year) %>%
    dplyr::summarise(effort_days = sum(num(.data$effort_days)), weeks = dplyr::n_distinct(.data$week), .groups = "drop")
  out <- dplyr::left_join(yr, caught, by = "year")
  out$mosquitoes[is.na(out$mosquitoes)] <- 0
  out$index <- round(out$mosquitoes / out$effort_days, 2)
  out$mosquitoes <- round(out$mosquitoes)
  out$partial <- out$weeks < 0.5 * stats::median(out$weeks)
  out$era <- NA_character_
  if (!is.null(effort) && all(c("year", "protocol_era") %in% names(effort))) {
    v <- effort[effort$valid_effort %in% TRUE, , drop = FALSE]
    era <- tapply(v$protocol_era, v$year, mode_chr)
    out$era <- unname(era[as.character(out$year)])
  }
  out$raw <- FALSE
  out[order(out$year), , drop = FALSE]
}

# every species caught at one grid (plotID) — powers the map click panel + CSV
grid_species <- function(obs, plotid) {
  sp <- target_only(species_level_only(obs)); sp <- sp[!is.na(sp$plotID) & sp$plotID == plotid, , drop = FALSE]
  if (!nrow(sp)) return(NULL)
  sp$.cnt <- num(sp$count)
  sp %>% dplyr::group_by(.data$scientificName) %>%
    dplyr::summarise(vernacular = mode_chr(.data$vernacularName), genus = mode_chr(.data$genus),
                     detections = dplyr::n(), mosquitoes = round(sum(.data$.cnt, na.rm = TRUE)), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(.data$mosquitoes), dplyr::desc(.data$detections))
}
# per-grid summary for the map: richness + activity per 24 trap-hours
point_summary <- function(obs, traps) {
  # Catch from every target row (genus-only identifications included, as in the
  # hero index); richness from species-level rows only.
  tg <- target_only(obs); tg$.cnt <- num(tg$count)
  caught <- tg %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(caught = sum(.data$.cnt, na.rm = TRUE), .groups = "drop")
  rich <- target_only(species_level_only(obs)) %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(richness = dplyr::n_distinct(.data$scientificName), .groups = "drop")
  per <- dplyr::full_join(caught, rich, by = "plotID")
  tv <- traps %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(lat = stats::median(num(.data$lat), na.rm = TRUE), lng = stats::median(num(.data$lng), na.rm = TRUE),
                     effort_days = sum(num(.data$effort_days), na.rm = TRUE), .groups = "drop")
  out <- dplyr::left_join(tv, per, by = "plotID")
  out$richness <- ifelse(is.na(out$richness), 0L, out$richness)
  out$caught <- ifelse(is.na(out$caught), 0, out$caught)
  out$per_24h <- ifelse(out$effort_days > 0, round(out$caught / out$effort_days, 1), NA_real_)
  out
}

# ---------------------------------------------------------------------------
# mos_qc(): data-quality flags for ONE species (the Taxon Profile). Ported from
# the bird app's bird_qc() contract. Returns ranked "verify, not wrong" flags
# PLUS the exact offending rows behind each, so the UI lists them (clickable)
# and the user can download a QC report. Thresholds grounded in the NEON
# DP1.10043.001 SOP (Fauna review; see docs/neonize-playbook.md).
#   high = the data contradicts itself (trapHours missing on a catch; targetTaxa=N w/ catch)
#   warn = worth a look (huge subsample expansion; compromised sample; day bout)
#   info = a note (bycatch; uncertain ID)
# Flagged rows are RETAINED, never deleted. Returns list(flags=…, sets=…).
# ---------------------------------------------------------------------------
CLEAN_CONDITION <- c("OK","good","No known compromise","NA")
mos_qc <- function(obs, sci, traps = NULL) {
  out <- list(flags = list(), sets = list())
  d <- species_detail(obs, sci); if (is.null(d) || !nrow(d)) return(out)
  cols <- intersect(c("scientificName","sampleID","plotID","trapID","year","collectDate","sex","count",
                      "trapHours","targetTaxaPresent","sampleCondition","nightOrDay",
                      "expansionFactor","identificationQualifier"), names(d))
  tidy <- function(rows, label) { x <- d[rows, cols, drop = FALSE]; if (!nrow(x)) return(NULL); x$flag <- label; x }
  add <- function(level, title, key, rows, detail) {
    rows <- rows[!is.na(rows)]; n <- length(rows); if (!n) return(invisible())
    out$flags[[length(out$flags) + 1L]] <<- list(level = level, title = title, key = key, n = n, detail = detail)
    out$sets[[key]] <<- tidy(rows, title)
  }
  th  <- if ("trapHours" %in% names(d)) num(d$trapHours) else rep(NA_real_, nrow(d))
  cnt <- if ("count" %in% names(d)) num(d$count) else rep(NA_real_, nrow(d))
  tgt <- if ("targetTaxaPresent" %in% names(d)) toupper(substr(as.character(d$targetTaxaPresent),1,1)) else rep(NA_character_, nrow(d))
  cond<- if ("sampleCondition" %in% names(d)) as.character(d$sampleCondition) else rep(NA_character_, nrow(d))
  nd  <- if ("nightOrDay" %in% names(d)) tolower(as.character(d$nightOrDay)) else rep(NA_character_, nrow(d))
  ef  <- if ("expansionFactor" %in% names(d)) num(d$expansionFactor) else rep(NA_real_, nrow(d))
  iq  <- if ("identificationQualifier" %in% names(d)) trimws(as.character(d$identificationQualifier)) else rep("", nrow(d))
  tgt2<- if ("is_target" %in% names(d)) d$is_target else rep(TRUE, nrow(d))

  # Unusable trap-hours and bycatch cannot reach a species' rows (the bundle
  # holds catch from intervals without usable duration, and the expert-ID table
  # is Culicidae only), so those checks run site-wide in site_qc() instead.
  # 2 — catch present but targetTaxaPresent = N (the data contradicts itself)
  add("high", "Catch present, but 'no target taxa' flagged", "targettaxa", which(tgt %in% "N" & is.finite(cnt) & cnt > 0),
      "The trapping record says no mosquitoes were present, yet identified mosquitoes were counted from it. One of the two is wrong; verify before trusting the count.")
  # 3 — large subsample expansion (a few counted scaled to hundreds = wide uncertainty)
  big <- which(is.finite(ef) & ef > 10)
  add("warn", "Large subsample expansion", "expansion", big,
      "Estimated count extrapolated from a small sorted subsample (expansion factor above 10x), so treat the count as approximate.")
  # 4 — compromised sampleCondition
  add("warn", "Compromised sample condition", "condition", which(!is.na(cond) & nzchar(cond) & !(cond %in% CLEAN_CONDITION)),
      "The sample was logged as damaged, spilled, moldy, or otherwise compromised, so its counts may be undercounts. Worth confirming before trusting them.")
  # 6 — uncertain identification (excluded from richness, kept in the total index)
  # Count exactly the rows the richness gate drops. nzchar(NA) is TRUE in R, so
  # the qualifier fallback (for bundles without is_species) must test NA first.
  unc <- if ("is_species" %in% names(d)) !(d$is_species %in% TRUE) else
    (!is.na(iq) & nzchar(iq) & !(tolower(iq) %in% c("na","none","not applicable"))) |
      (("taxonRank" %in% names(d)) & !(d$taxonRank %in% c("species","subspecies")))
  add("info", "Uncertain identification", "uncertain", which(unc),
      "An identification qualifier (for example 'cf.' or 'near') or a coarser-than-species rank is recorded. These are excluded from richness but kept in the total activity index.")
  # 7 — daytime interval (a STANDARD half of a NEON bout, not an error). Per the
  # TOS protocol (NEON.DOC.014049) a bout = one night interval + the following day
  # interval, so day collections are legitimate and ARE included in the index +
  # denominator alongside night collections. This is an INFO note, not a warning.
  add("info", "Daytime trap interval", "daybout", which(nd %in% "day"),
      "Collected on the daytime half of a NEON bout (a bout is one night interval plus the following day interval). Day collections are standard and are counted in the activity index and its denominator, the same as night collections. Listed only so you can see the night/day split.")
  out
}
# Site-level data-quality summary over every target row, genus and family rank
# included, plus the effort and held-identification audit trail that never
# reaches a species profile. Returns list(rows = data.frame(check, n, detail),
# held = held_identifications) for the Overview card and its CSV.
site_qc <- function(obs, effort = NULL, held = NULL, meta = NULL) {
  tg <- target_only(obs); n_tg <- if (is.null(tg)) 0L else nrow(tg)
  ef <- if (n_tg && "expansionFactor" %in% names(tg)) num(tg$expansionFactor) else numeric(0)
  cond <- if (n_tg && "sampleCondition" %in% names(tg)) as.character(tg$sampleCondition) else character(0)
  coarse <- if (n_tg && "is_species" %in% names(tg)) sum(!(tg$is_species %in% TRUE)) else 0L
  st <- if (!is.null(effort) && "effort_status" %in% names(effort)) table(factor(effort$effort_status,
    levels = c("valid_sampled", "not_sampled", "unusable_duration", "unusable_identity"))) else NULL
  oc <- if (!is.null(effort) && "outcome_status" %in% names(effort)) table(factor(effort$outcome_status[effort$valid_effort %in% TRUE],
    levels = c("positive_catch", "zero_catch", "catch_unusable_or_pending", "outcome_unknown"))) else NULL
  hr <- if (!is.null(held) && nrow(held) && "hold_reason" %in% names(held)) table(held$hold_reason) else integer(0)
  hold_text <- c(held_unmatched_sorting = "no matching sorting record", held_unmatched_effort = "no matching trap interval",
                 held_invalid_proportion = "unusable subsample proportion", held_invalid_effort = "interval not sampled or unusable",
                 held_nonpositive_count = "zero or missing count")
  rows <- data.frame(check = character(0), n = integer(0), detail = character(0), stringsAsFactors = FALSE)
  add <- function(check, n, detail) rows[nrow(rows) + 1L, ] <<- list(check, as.integer(n), detail)
  if (!is.null(st)) {
    add("Intervals sampled", st[["valid_sampled"]], "Day or night trap intervals NEON records as sampled with usable duration.")
    add("Intervals not sampled", st[["not_sampled"]], "NEON recorded why the trap did not run (snow, flooding, low temperature, logistics, management, weather, other).")
    add("Intervals without usable trap-hours", st[["unusable_duration"]], "Sampled, but the duration is missing or zero, so the interval is left out of every rate.")
  }
  if (!is.null(oc)) add("Sampled intervals with catch still pending or unknown",
    oc[["catch_unusable_or_pending"]] + oc[["outcome_unknown"]],
    "Identification is pending, held, or was never reported. These intervals are left out of the rate denominators rather than counted as zero.")
  add("Records identified only to genus or family", coarse, "Counted in the site index, left out of species richness and the species charts.")
  add("Records from a large subsample expansion", sum(is.finite(ef) & ef > 10), "The identified count was scaled up more than 10x to the whole trap.")
  add("Records from a compromised sample", sum(!is.na(cond) & nzchar(cond) & !(cond %in% CLEAN_CONDITION)), "Damaged, spilled or otherwise compromised; counts may be low.")
  for (k in names(hr)) add(paste0("Identifications held: ", hold_text[[k]] %||% k), hr[[k]], "Kept in the bundle's audit table and left out of every count.")
  list(rows = rows, held = held)
}
mos_qc_report <- function(obs, sci, traps = NULL) {
  q <- mos_qc(obs, sci, traps); if (!length(q$sets)) return(NULL)
  do.call(rbind, c(q$sets, list(make.row.names = FALSE)))
}

# ---------------------------------------------------------------------------
# Machine-readable column codebook for the CSV downloads (FAIR data dictionary).
# ---------------------------------------------------------------------------
mos_codebook <- function() {
  base <- data.frame(
    column = c("scientificName","vernacularName","genus","sampleID","trapkey","plotID","trapID","year","collectDate",
               "sex","count","is_target","nightOrDay","trapHours","proportionIdentified","expansionFactor",
               "targetTaxaPresent","sampleCondition","identificationQualifier","nativeStatusCode",
               "index","ubiquity","female_share","effort_days","mos_per_24h","culex_share","S_obs","chao2","coverage","S_rare",
               "coarse_share","top_share","denominator_ok","unavailable_days"),
    units = c("","","","","","","","year","date","F/M/U","# mosquitoes (est.)","logical","night/day","hours","0-1","x",
              "Y/N","category","qualifier","code","per 24 trap-hours","% of occasions","% of sexed","24-hour units",
              "per 24 trap-hours","% of catch","# species","# species","0-1","# species",
              "0-1","% of catch","logical","24-hour units"),
    description = c(
      "Accepted scientific (Latin) name of the mosquito species.",
      "Common name where one exists.",
      "Genus (Culex, Aedes, Anopheles, Culiseta, Psorophora, ...). Culex is retained as descriptive taxonomic context; this product has no pathogen or health-risk result.",
      "NEON sample identifier linking a non-empty trap sample to sorting. It may be absent for zero catches, so it is not the incidence key.",
      "Trap key = plotID; DP1.10043.001 deploys one CO2 trap per plot per night (no separate trapID).",
      "NEON plot (grid) identifier, the fixed spot a CO2 trap is set.",
      "The plot's trap location (the plotID numeric suffix).",
      "Calendar year of the collection.",
      "Date the trap was collected.",
      "Sex of the individuals. CO2 traps catch overwhelmingly host-seeking FEMALES by design; a near-all-female catch is the trap working, not a population fact. U = undetermined.",
      "ESTIMATED number of mosquitoes = identified count scaled to the whole trap by 1 / proportionIdentified. Continuous; rounded only at display.",
      "TRUE if a target mosquito (family Culicidae). The expert-ID table is Culicidae only, so this is effectively all rows; bycatch is not carried in this product.",
      "Night or day interval. A NEON bout is one night interval plus the following day interval; BOTH are standard and both are counted in the activity index and its denominator.",
      "Trap interval duration in hours; trapHours/24 is the continuous 24-hour effort denominator. NA/0 is unavailable effort, not a zero catch.",
      "Fraction of the trap's catch that NEON identified (mos_sorting). The whole-trap count = individualCount / proportionIdentified.",
      "Subsample expansion factor (= 1 / proportionIdentified) applied to scale the identified count to the whole trap.",
      "NEON flag for whether target taxa were present in the trap (Y/N).",
      "Condition of the sample on receipt; compromised conditions may undercount.",
      "Identification qualifier (e.g. cf., near); flags an uncertain ID. Excluded from richness, kept in the index.",
      "Native / introduced status code.",
      "Activity index = whole-trap-scaled count / (sum trapHours/24). A within-site index of host-seeking activity, NOT a population.",
      "% of collection occasions (sampled intervals) where the species was ever caught. Less catch-biased than the index, still detection-bound.",
      "% of sexed individuals that were female. A CO2-trap method signature (traps select females), not a population sex ratio.",
      "Resolved effort in 24-hour units = sum(trapHours)/24 over sampled intervals whose catch is known (a catch or NEON's no-target-taxa flag); the index denominator. Intervals with pending or unknown catch are counted separately and left out.",
      "Site activity index = total whole-trap-scaled catch / resolved effort in 24-hour units.",
      "Culex share of the whole-trap catch; descriptive taxonomy only, with no pathogen or health-risk inference.",
      "Observed species richness (species caught).",
      "Chao2 incidence-based richness estimate (a bias-corrected MINIMUM; unstable when few species are caught at exactly two occasions). Chao 1987.",
      "Incidence sample coverage, 0-1 (share of trap records that belong to species already caught; near 1 means the uncaught species are rare in these traps, not that few species are missing). Chao & Jost 2012.",
      "Species richness RAREFIED to a common number of collection occasions across sites (incidence rarefaction; Colwell et al. 2012).",
      "Share of the site's whole-trap catch identified only to genus or family: counted in the site index, left out of species richness and the species charts.",
      "Share of the site's whole-trap catch from its single largest collection record (one sample can dominate after subsample expansion).",
      "Effort table: TRUE when a sampled interval's catch is known (target catch, or NEON flagged no target taxa); only these intervals enter rate denominators.",
      "Effort table: 24-hour units of sampled effort whose catch is pending, held or unknown; disclosed, left out of rates."),
    stringsAsFactors = FALSE)

  # Columns that appear ONLY in the per-grid species CSV (map click) and the
  # Across-the-continent cross-site CSV — documented here so every download is
  # self-describing.
  grid <- data.frame(
    column = c("vernacular","detections","mosquitoes"),
    units  = c("", "# sampled intervals", "# mosquitoes (est.)"),
    description = c(
      "Grid CSV: common name where one exists (same as vernacularName; named `vernacular` in the per-grid export).",
      "Grid CSV: number of collection occasions (sampled intervals) at this grid where the species was caught.",
      "Grid CSV / yearly chart: ESTIMATED whole-trap-scaled mosquito count summed for the species (same scaling as `count`). The yearly chart divides it by that year's resolved effort."),
    stringsAsFactors = FALSE)

  cross <- data.frame(
    column = c("site","name","state","biome_lab","warm_temp_c","mat_c","monsoon_precip_mm","precip_annual_mm",
               "has_gauge","effort_days","collections","mos_per_24h","taxa","t_used","hill_q1","hill_q2","mean_ubiquity","pct_culex",
               "top_taxon","top_genus"),
    units  = c("code","","","","°C","°C","mm","mm","logical","24-hour units","# occasions","per 24 trap-hours","# species","# occasions",
               "effective # species","effective # species","% of occasions","% of catch","",""),
    description = c(
      "Cross-site CSV: NEON 4-letter site code.",
      "Cross-site CSV: site name.",
      "Cross-site CSV: US state.",
      "Cross-site CSV: biome label (warm desert, cold desert, grassland, forest, ...).",
      "Cross-site CSV: mean warm-season (summer) air temperature, the degree-day axis for cooler sites. From the env overlays; NA where no gauge.",
      "Cross-site CSV: mean annual air temperature.",
      "Cross-site CSV: total precipitation in the site's supported summer-rain window, shown as descriptive seasonal context. NA where no gauge.",
      "Cross-site CSV: total annual precipitation.",
      "Cross-site CSV: TRUE if the site has a co-located NEON precipitation gauge; FALSE sites fall back to a climatology and cannot anchor a monsoon window.",
      "Cross-site CSV: resolved trap effort as sum(trapHours/24) over intervals with a known catch.",
      "Cross-site CSV: number of collection occasions (sampled intervals with usable effort) the site's numbers are built on.",
      "Cross-site CSV: whole-trap-scaled target catch divided by resolved 24-hour effort units; a within-site activity index.",
      "Cross-site CSV: number of mosquito species (taxa) observed at the site.",
      "Cross-site CSV: the common occasion count that S_rare was rarefied DOWN to (the min across compared sites).",
      "Cross-site CSV: Hill number q=1 (exp Shannon): effective species count from incidence frequencies (share of sampled intervals), not catch size.",
      "Cross-site CSV: Hill number q=2 (inverse Simpson) on incidence frequencies: effective species count, the most frequently caught species emphasised.",
      "Cross-site CSV: mean ubiquity across the site's species (% of occasions present, averaged).",
      "Cross-site CSV: Culex share of the site's whole-trap catch (same as culex_share); no pathogen or health-risk inference.",
      "Cross-site CSV: the most-active species at the site.",
      "Cross-site CSV: the most-active genus at the site."),
    stringsAsFactors = FALSE)

  pulse <- data.frame(
    column = c("week","index_median","q25","q75","n_years","monsoon_month_min","monsoon_month_max"),
    units  = c("week of year, Sunday start (R %U, 00-53)","per 24 trap-hours","per 24 trap-hours","per 24 trap-hours","# years","month","month"),
    description = c(
      "Pulse CSV: week of the year counted from Sunday (R format %U, weeks 00-53). Not an ISO 8601 week.",
      "Pulse CSV: median activity index across years for this week (the headline pulse line). Median, not mean, because catch is heavily skewed.",
      "Pulse CSV: 25th percentile of the yearly activity index for this week (lower edge of the shaded band).",
      "Pulse CSV: 75th percentile of the yearly activity index for this week (upper edge of the shaded band; the band holds the middle 50% of years).",
      "Pulse CSV: number of years contributing a value for this week.",
      "Pulse CSV: first month of the site's summer-monsoon window (NA where the site has no NEON gauge / no summer-rain peak).",
      "Pulse CSV: last month of the site's summer-monsoon window (NA where the site has no NEON gauge / no summer-rain peak)."),
    stringsAsFactors = FALSE)

  # Provenance / license row (NEON CC BY 4.0), first so it's visible on open.
  lic <- data.frame(
    column = "_source",
    units  = "license",
    description = "Source: NEON DP1.10043.001, CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/); aggregated and derived by this app.",
    stringsAsFactors = FALSE)
  rbind(lic, base, grid, cross, pulse)
}
