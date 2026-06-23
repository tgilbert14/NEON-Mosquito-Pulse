# ===========================================================================
# NEON Mosquito Pulse — mos_helpers.R
# CO2-trap mosquito analyses on DP1.10043.001. The honesty backbone: a CO2
# trap lures HOST-SEEKING FEMALES, and big catches are subsampled then weight-
# expanded, so the abundance axis is an ACTIVITY INDEX (mosquitoes per
# trap-night), never a population. A trap-night = one CO2 trap run for one
# ~24h collection bout; trapHours/24 is the effort denominator. A collection
# occasion (one sampleID) is the incidence replicate for richness, the mosquito
# analogue of the bird app's point x year. See docs/neonize-playbook.md.
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
#   index    = activity index = whole-trap-scaled count / trap-nights (per trap-night)
#   ubiquity = % of ATTEMPTED collection occasions where ever caught (a steadier,
#              less catch-biased axis than the index, though still detection-bound)
#   female_share = % of sexed individuals that were female (a TRAP signature)
# n_occ = total collection occasions ATTEMPTED at the site (from the effort/trapping
# table, INCLUDING zero-catch nights), NOT n_distinct over the catch-only obs — else
# ubiquity inflates (the suite's "join LEFT, keep the zeros" honesty rule).
# ---------------------------------------------------------------------------
vector_board <- function(obs, n_occ = NULL, trap_nights = NULL) {
  sp <- target_only(species_level_only(obs)); if (is.null(sp) || !nrow(sp)) return(NULL)
  sp$.occ <- collection_occasion(sp)   # the trap-night occasion (occ_id), not sampleID
  tn <- max(1, num(trap_nights %||% dplyr::n_distinct(sp$.occ)))
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

# site headline (hero stats). index = site activity index (per trap-night).
site_vectors <- function(obs, n_occ = NULL, trap_nights = NULL, effort_week = NULL, n_traps = NA) {
  brd <- vector_board(obs, n_occ, trap_nights); if (is.null(brd)) return(NULL)
  tn <- max(1, num(trap_nights %||% dplyr::n_distinct(obs$sampleID)))
  fem <- sum(brd$female, na.rm = TRUE); mal <- sum(brd$male, na.rm = TRUE)
  culex <- sum(brd$total[brd$genus == "Culex"], na.rm = TRUE); tot <- sum(brd$total, na.rm = TRUE)
  pk <- pulse_phenology(obs, effort_week); peak_wk <- if (!is.null(pk) && nrow(pk)) pk$week[which.max(pk$index)] else NA_integer_
  list(n_taxa = nrow(brd), index = round(tot / tn, 2),
       pct_female = if (fem + mal > 0) round(100 * fem / (fem + mal)) else NA_real_,
       culex_share = if (tot > 0) round(100 * culex / tot) else NA_real_,
       peak_week = peak_wk, n_traps = n_traps,
       trap_nights = round(tn), n_collections = as.integer(n_occ %||% dplyr::n_distinct(obs$sampleID)),
       top = brd$vernacular[which.max(brd$index)] %||% brd$scientificName[which.max(brd$index)])
}

# ---------------------------------------------------------------------------
# The MONSOON PULSE — activity index by week-of-year, averaged across years.
# Per (year, week): whole-trap catch / TRAP-NIGHTS of effort that week (from the
# effort_week table, which counts ALL attempted trap deployments INCLUDING
# zero-catch nights). Dividing by effort, not by caught-occasion count, keeps the
# shoulder-week zeros honest so the monsoon contrast isn't flattened (the suite's
# "keep the zeros" rule; matches the hero per-trap-night denominator). Weeks with
# no trapping at all are absent (a gap), never a zero. The app's signature chart.
# ---------------------------------------------------------------------------
week_of <- function(d) as.integer(format(as.Date(substr(as.character(d), 1, 10)), "%U"))
pulse_phenology <- function(obs, effort_week = NULL) {
  sp <- target_only(obs); if (is.null(sp) || !nrow(sp)) return(NULL)
  if (!"week" %in% names(sp)) sp$week <- week_of(sp$collectDate)
  sp$.cnt <- num(sp$count); sp <- sp[is.finite(sp$week), , drop = FALSE]; if (!nrow(sp)) return(NULL)
  catch <- sp %>% dplyr::group_by(.data$year, .data$week) %>%
    dplyr::summarise(total = sum(.data$.cnt, na.rm = TRUE), n_occ = dplyr::n_distinct(.data$sampleID), .groups = "drop")
  if (!is.null(effort_week) && nrow(effort_week) && "trap_nights" %in% names(effort_week)) {
    ew <- effort_week; ew$.eff <- num(ew$trap_nights); ew <- ew[is.finite(ew$.eff) & ew$.eff > 0, , drop = FALSE]
    yw <- dplyr::left_join(ew[, c("year", "week", ".eff")], catch[, c("year", "week", "total")], by = c("year", "week"))
    yw$total[is.na(yw$total)] <- 0           # an attempted week with no catch is a real 0, not a gap
    yw$idx <- yw$total / yw$.eff             # mosquitoes per trap-night of effort that week
  } else {                                   # fallback: per-caught-occasion (no effort table available)
    yw <- catch; yw$idx <- yw$total / pmax(1L, yw$n_occ)
  }
  # Across years per week: the MEDIAN, not the mean. Mosquito catch is wildly
  # skewed and outlier-prone (one fluke year can be 1000x a normal week), so a
  # mean lets a single freak January collection masquerade as the seasonal peak.
  # The median gives the typical year's pulse (standard in mosquito surveillance);
  # the band is the inter-quartile spread, so noisy weeks read as noisy.
  yw %>% dplyr::group_by(.data$week) %>%
    dplyr::summarise(index = stats::median(.data$idx),
                     se = if (dplyr::n() > 1) stats::IQR(.data$idx) / 2 else 0,
                     n_years = dplyr::n(), .groups = "drop") %>%
    dplyr::arrange(.data$week)
}

# genus composition (shares of whole-trap catch)
genus_share <- function(obs) {
  sp <- target_only(species_level_only(obs)); if (is.null(sp) || !nrow(sp)) return(NULL)
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
# Incidence richness on COLLECTION OCCASIONS (one sampleID = one trap-night
# collection), the mosquito analogue of the bird point x year occasion.
# Chao2 (Chao 1987; Colwell et al. 2012). Genus-only IDs excluded from richness.
# ---------------------------------------------------------------------------
# the sampling occasion = a TRAP-NIGHT (occ_id = plotID+collectDate), which the
# bundler builds to include zero-catch nights. Falls back to sampleID for old bundles.
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
  chao <- if (Q2 > 0) S + corr * Q1^2 / (2 * Q2) else S + corr * Q1 * (Q1 - 1) / 2
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
mos_accum <- function(obs, traps = NULL, perms = 40) {
  sp <- target_only(species_level_only(obs)); if (is.null(sp) || !nrow(sp)) return(NULL)
  occ_id <- as.integer(factor(collection_occasion(sp))); k <- max(occ_id); if (k < 2) return(NULL)
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
catch_by_year <- function(obs, sci) {
  d <- species_detail(obs, sci); if (is.null(d)) return(NULL)
  d$.cnt <- num(d$count)
  d %>% dplyr::group_by(.data$year) %>% dplyr::summarise(mosquitoes = round(sum(.data$.cnt, na.rm = TRUE)), .groups = "drop")
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
# per-grid summary for the map: richness + activity per trap-night
point_summary <- function(obs, traps) {
  sp <- target_only(species_level_only(obs)); sp$.cnt <- num(sp$count)
  per <- sp %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(richness = dplyr::n_distinct(.data$scientificName), caught = sum(.data$.cnt, na.rm = TRUE), .groups = "drop")
  tv <- traps %>% dplyr::group_by(.data$plotID) %>%
    dplyr::summarise(lat = stats::median(num(.data$lat), na.rm = TRUE), lng = stats::median(num(.data$lng), na.rm = TRUE),
                     trap_nights = sum(num(.data$trap_nights), na.rm = TRUE), .groups = "drop")
  out <- dplyr::left_join(tv, per, by = "plotID")
  out$richness <- ifelse(is.na(out$richness), 0L, out$richness)
  out$per_tn <- ifelse(out$trap_nights > 0, round(out$caught / out$trap_nights, 1), NA_real_)
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

  # 1 — trapHours missing or zero on a row that has catch (can't normalize -> dropped from denominator)
  add("high", "Trap-hours missing or zero", "traphours", which((is.na(th) | th == 0) & is.finite(cnt) & cnt > 0),
      "These collections have catch but no usable trapHours, so they can't be turned into a per-trap-night rate and are dropped from the index denominator. A trap deployment with no recorded duration is unusable as effort.")
  # 2 — catch present but targetTaxaPresent = N (the data contradicts itself)
  add("high", "Catch present, but 'no target taxa' flagged", "targettaxa", which(tgt %in% "N" & is.finite(cnt) & cnt > 0),
      "The trapping record says no mosquitoes were present, yet identified mosquitoes were counted from it. One of the two is wrong; verify before trusting the count.")
  # 3 — large subsample expansion (a few counted scaled to hundreds = wide uncertainty)
  big <- which(is.finite(ef) & ef > 10)
  add("warn", "Large subsample expansion", "expansion", big,
      "Estimated count extrapolated from a small sorted subsample (expansion factor > 10x) — treat the abundance as approximate.")
  # 4 — compromised sampleCondition
  add("warn", "Compromised sample condition", "condition", which(!is.na(cond) & nzchar(cond) & !(cond %in% CLEAN_CONDITION)),
      "The sample was logged as damaged, spilled, moldy, or otherwise compromised, so its counts may be undercounts. Worth confirming before trusting them.")
  # 5 — non-mosquito bycatch leaked into the ID stream
  add("info", "Non-mosquito bycatch", "bycatch", which(tgt2 %in% FALSE),
      "Rows flagged as bycatch (non-Culicidae) appear in this species' records. Bycatch is excluded from the activity index and richness, listed here for transparency.")
  # 6 — uncertain identification (excluded from richness, kept in the total index)
  add("info", "Uncertain identification", "uncertain", which((nzchar(iq)) | (("taxonRank" %in% names(d)) & !(d$taxonRank %in% c("species","subspecies")))),
      "An identification qualifier (for example 'cf.' or 'near') or a coarser-than-species rank is recorded. These are excluded from richness but kept in the total activity index.")
  # 7 — daytime interval (a STANDARD half of a NEON bout, not an error). Per the
  # TOS protocol (NEON.DOC.014049) a bout = one night interval + the following day
  # interval, so day collections are legitimate and ARE included in the index +
  # denominator alongside night collections. This is an INFO note, not a warning.
  add("info", "Daytime trap interval", "daybout", which(nd %in% "day"),
      "Collected on the daytime half of a NEON bout (a bout is one night interval plus the following day interval). Day collections are standard and are counted in the activity index and its denominator, the same as night collections. Listed only so you can see the night/day split.")
  out
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
               "index","ubiquity","female_share","trap_nights","mos_per_tn","culex_share","S_obs","chao2","coverage","S_rare"),
    units = c("","","","","","","","year","date","F/M/U","# mosquitoes (est.)","logical","night/day","hours","0-1","x",
              "Y/N","category","qualifier","code","per trap-night","% of occasions","% of sexed","# trap-nights",
              "per trap-night","% of catch","# species","# species","0-1","# species"),
    description = c(
      "Accepted scientific (Latin) name of the mosquito species.",
      "Common name where one exists.",
      "Genus (Culex, Aedes, Anopheles, Culiseta, Psorophora, ...). Culex is the main West Nile vector.",
      "NEON sample identifier = one trap deployment / collection event (one trap-night). The incidence replicate.",
      "Trap key = plotID; DP1.10043.001 deploys one CO2 trap per plot per night (no separate trapID).",
      "NEON plot (grid) identifier, the fixed spot a CO2 trap is set.",
      "The plot's trap location (the plotID numeric suffix).",
      "Calendar year of the collection.",
      "Date the trap was collected.",
      "Sex of the individuals. CO2 traps catch overwhelmingly host-seeking FEMALES by design; a near-all-female catch is the trap working, not a population fact. U = undetermined.",
      "ESTIMATED number of mosquitoes = identified count scaled to the whole trap by 1 / proportionIdentified. Continuous; rounded only at display.",
      "TRUE if a target mosquito (family Culicidae). The expert-ID table is Culicidae only, so this is effectively all rows; bycatch is not carried in this product.",
      "Night or day interval. A NEON bout is one night interval plus the following day interval; BOTH are standard and both are counted in the activity index and its denominator.",
      "Trap deployment duration in hours; trapHours/24 = trap-nights, the effort denominator. NA/0 = no usable effort, dropped from the denominator (not a zero catch).",
      "Fraction of the trap's catch that NEON identified (mos_sorting). The whole-trap count = individualCount / proportionIdentified.",
      "Subsample expansion factor (= 1 / proportionIdentified) applied to scale the identified count to the whole trap.",
      "NEON flag for whether target taxa were present in the trap (Y/N).",
      "Condition of the sample on receipt; compromised conditions may undercount.",
      "Identification qualifier (e.g. cf., near); flags an uncertain ID. Excluded from richness, kept in the index.",
      "Native / introduced status code.",
      "Activity index = whole-trap-scaled count / trap-nights. A within-site index of host-seeking activity, NOT a population.",
      "% of collection occasions (trap-nights) where the species was ever caught. Less catch-biased than the index, still detection-bound.",
      "% of sexed individuals that were female. A CO2-trap method signature (traps select females), not a population sex ratio.",
      "Trap-nights = sum(trapHours)/24 at the site; the index denominator.",
      "Site activity index = total whole-trap-scaled catch / trap-nights.",
      "Culex (West Nile vector group) share of the whole-trap catch.",
      "Observed species richness (species caught).",
      "Chao2 incidence-based richness estimate (a bias-corrected MINIMUM; unstable when few species are caught at exactly two occasions). Chao 1987.",
      "Sample-coverage completeness, 0-1 (fraction of the community caught). Chao & Jost 2012.",
      "Species richness RAREFIED to a common number of collection occasions across sites (incidence rarefaction; Colwell et al. 2012)."),
    stringsAsFactors = FALSE)

  # Columns that appear ONLY in the per-grid species CSV (map click) and the
  # Across-the-continent cross-site CSV — documented here so every download is
  # self-describing.
  grid <- data.frame(
    column = c("vernacular","detections","mosquitoes"),
    units  = c("", "# trap-nights", "# mosquitoes (est.)"),
    description = c(
      "Grid CSV: common name where one exists (same as vernacularName; named `vernacular` in the per-grid export).",
      "Grid CSV: number of collection occasions (trap-nights) at this grid where the species was caught.",
      "Grid CSV / yearly card: ESTIMATED whole-trap-scaled mosquito count summed for the species (same scaling as `count`)."),
    stringsAsFactors = FALSE)

  cross <- data.frame(
    column = c("site","name","state","biome_lab","warm_temp_c","mat_c","monsoon_precip_mm","precip_annual_mm",
               "has_gauge","collections","taxa","t_used","hill_q1","hill_q2","mean_ubiquity","pct_culex",
               "top_taxon","top_genus"),
    units  = c("code","","","","°C","°C","mm","mm","logical","# occasions","# species","# occasions",
               "effective # species","effective # species","% of occasions","% of catch","",""),
    description = c(
      "Cross-site CSV: NEON 4-letter site code.",
      "Cross-site CSV: site name.",
      "Cross-site CSV: US state.",
      "Cross-site CSV: biome label (warm desert, cold desert, grassland, forest, ...).",
      "Cross-site CSV: mean warm-season (summer) air temperature, the degree-day axis for cooler sites. From the env overlays; NA where no gauge.",
      "Cross-site CSV: mean annual air temperature.",
      "Cross-site CSV: total precipitation in the site's summer-monsoon window (the water-limited driver). NA where no gauge.",
      "Cross-site CSV: total annual precipitation.",
      "Cross-site CSV: TRUE if the site has a co-located NEON precipitation gauge; FALSE sites fall back to a climatology and cannot anchor a monsoon window.",
      "Cross-site CSV: number of collection occasions (trap-nights with usable effort) the site's numbers are built on.",
      "Cross-site CSV: number of mosquito species (taxa) observed at the site.",
      "Cross-site CSV: the common occasion count that S_rare was rarefied DOWN to (the min across compared sites).",
      "Cross-site CSV: Hill number q=1 (exp Shannon) — effective species count weighting by activity, common species emphasised.",
      "Cross-site CSV: Hill number q=2 (inverse Simpson) — effective species count, dominant species emphasised.",
      "Cross-site CSV: mean ubiquity across the site's species (% of occasions present, averaged).",
      "Cross-site CSV: Culex (West Nile vector group) share of the site's whole-trap catch (same as culex_share).",
      "Cross-site CSV: the most-active species at the site.",
      "Cross-site CSV: the most-active genus at the site."),
    stringsAsFactors = FALSE)

  pulse <- data.frame(
    column = c("week","index_median","iqr","n_years","monsoon_month_min","monsoon_month_max"),
    units  = c("ISO week","per trap-night","per trap-night","# years","month","month"),
    description = c(
      "Pulse CSV: ISO week of the year (0-53).",
      "Pulse CSV: median activity index across years for this week (the headline pulse line). Median, not mean, because catch is heavily skewed.",
      "Pulse CSV: inter-quartile range across years for this week (the shaded band = the middle 50% of years).",
      "Pulse CSV: number of years contributing a value for this week.",
      "Pulse CSV: first month of the site's summer-monsoon window (NA where the site has no NEON gauge / no summer-rain peak).",
      "Pulse CSV: last month of the site's summer-monsoon window (NA where the site has no NEON gauge / no summer-rain peak)."),
    stringsAsFactors = FALSE)

  rbind(base, grid, cross, pulse)
}
