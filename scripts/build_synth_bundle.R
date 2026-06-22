# ===========================================================================
# build_synth_bundle.R — representative PLACEHOLDER data so the app + cover
# render real-looking mosquito numbers PENDING the real DP1.10043.001 fetch.
# These are NOT measurements. Deterministic (set.seed) so re-runs are byte-stable.
#
# Biome-conditional ecology (per the suite's biome-conditional-priors insight):
#   desert sites get a strong Culex summer-MONSOON pulse + modest richness;
#   tundra near-zero catch; forest/grassland mid. This makes the cross-site
#   monsoon gradient and the desert-pulse headline LOOK like the real signal
#   without faking precision. Every bundle is marked meta$synthetic = TRUE, so
#   global.R shows an honest "preview build" banner. When fetch_mos_all.R +
#   bundle_mos_data.R later run for real, they overwrite these files and the
#   banner auto-disappears.
#
#   Rscript scripts/build_synth_bundle.R
# ===========================================================================
set.seed(43)
suppressWarnings(suppressMessages(source("R/site_metadata.R")))
dir.create("data/sites", recursive = TRUE, showWarnings = FALSE)
dir.create("data-sample", showWarnings = FALSE)

BIOME <- c(SRER="desert", JORN="desert", MOAB="desert", ONAQ="desert",
  BARR="tundra", TOOL="tundra", NIWO="tundra",
  WOOD="grassland", DCFS="grassland", NOGP="grassland", KONZ="grassland", KONA="grassland",
  CPER="grassland", STER="grassland", OAES="grassland", CLBJ="grassland", YELL="grassland", SJER="grassland",
  GUAN="tropical", LAJA="tropical")
biome_of <- function(s) { b <- unname(BIOME[s]); ifelse(is.na(b), "forest", b) }

TAXA <- data.frame(
  scientificName = c("Culex tarsalis","Culex quinquefasciatus","Culex erythrothorax","Culex pipiens",
    "Aedes vexans","Aedes aegypti","Aedes dorsalis","Aedes sollicitans","Aedes nigromaculis","Aedes communis",
    "Anopheles freeborni","Anopheles punctipennis","Culiseta inornata","Culiseta incidens",
    "Psorophora columbiae","Psorophora signipennis","Coquillettidia perturbans"),
  genus = c("Culex","Culex","Culex","Culex","Aedes","Aedes","Aedes","Aedes","Aedes","Aedes",
    "Anopheles","Anopheles","Culiseta","Culiseta","Psorophora","Psorophora","Coquillettidia"),
  vernacular = c("western encephalitis mosquito","southern house mosquito","tule mosquito","northern house mosquito",
    "inland floodwater mosquito","yellow fever mosquito","summer salt-marsh mosquito","eastern salt-marsh mosquito",
    "irrigated-pasture mosquito","snowmelt mosquito","western malaria mosquito","woodland malaria mosquito",
    "winter marsh mosquito","cool-weather mosquito","dark rice-field mosquito","desert floodwater mosquito","cattail mosquito"),
  stringsAsFactors = FALSE)

# biome parameters: seasonal peak week, spread, base catch, traps, weeks trapped,
# precip gauge present, Culex up-weight, and the candidate species pool.
params <- function(b) switch(b,
  desert    = list(peak=31, sd=4.0, base=16, ntraps=4, weeks=22:42, gauge=TRUE,  culexw=4.0,
                   pool=c("Culex tarsalis","Culex quinquefasciatus","Culex erythrothorax","Aedes vexans",
                          "Aedes dorsalis","Aedes nigromaculis","Anopheles freeborni","Culiseta inornata",
                          "Psorophora columbiae","Psorophora signipennis")),
  grassland = list(peak=27, sd=6.0, base=11, ntraps=5, weeks=18:40, gauge=TRUE,  culexw=2.2,
                   pool=c("Culex tarsalis","Aedes vexans","Aedes dorsalis","Anopheles freeborni",
                          "Anopheles punctipennis","Culiseta inornata","Psorophora columbiae","Coquillettidia perturbans")),
  forest    = list(peak=25, sd=7.0, base=9,  ntraps=5, weeks=16:40, gauge=TRUE,  culexw=1.5,
                   pool=c("Culex pipiens","Aedes vexans","Aedes communis","Anopheles punctipennis",
                          "Culiseta incidens","Coquillettidia perturbans","Psorophora columbiae")),
  tropical  = list(peak=40, sd=11,  base=14, ntraps=4, weeks=1:52,  gauge=TRUE,  culexw=2.8,
                   pool=c("Culex quinquefasciatus","Aedes aegypti","Aedes sollicitans","Anopheles punctipennis",
                          "Culex tarsalis","Psorophora columbiae")),
  tundra    = list(peak=28, sd=3.0, base=3,  ntraps=3, weeks=24:34, gauge=FALSE, culexw=0.4,
                   pool=c("Aedes communis","Aedes vexans","Culiseta inornata")))

YEARS <- 2019:2022; CLEAN <- "OK"
tx_row <- function(sci) TAXA[match(sci, TAXA$scientificName), ]

mk_site <- function(s) {
  b <- biome_of(s); P <- params(b); mr <- neon_sites[neon_sites$site == s, ]
  ntr <- P$ntraps
  traps_meta <- data.frame(
    trapkey = paste0(s, "_T", sprintf("%02d", 1:ntr)),
    plotID  = paste0(s, "_0", ((1:ntr) %% 3) + 1),
    trapID  = sprintf("T%02d", 1:ntr),
    nlcdClass = "shrubScrub",
    lat = mr$lat + rnorm(ntr, 0, 0.012), lng = mr$lng + rnorm(ntr, 0, 0.012),
    stringsAsFactors = FALSE)
  pool_w <- ifelse(tx_row(P$pool)$genus == "Culex", P$culexw, 1)
  obs_rows <- list(); occ_rows <- list(); occ_tn <- 0; occ_n <- 0; r <- 0L
  for (yr in YEARS) for (ti in 1:ntr) {
    # this trap is run on a sample of the season's weeks
    wk_set <- sort(sample(P$weeks, size = max(4, round(length(P$weeks) * 0.45))))
    for (wk in wk_set) {
      occ_n <- occ_n + 1L
      th <- runif(1, 20, 24); tn <- th / 24; occ_tn <- occ_tn + tn
      # record EVERY attempted occasion (incl. zero-catch) as effort, so the
      # pulse / ubiquity denominators use true effort, not caught-occasion count.
      occ_rows[[occ_n]] <- data.frame(year = yr, week = wk, trapkey = traps_meta$trapkey[ti], trap_nights = tn)
      sid <- sprintf("%s.%d.T%02d.W%02d", s, yr, ti, wk)
      cdate <- as.Date(paste0(yr, "-01-01")) + (wk * 7L)
      sw <- exp(-0.5 * ((wk - P$peak) / P$sd)^2)            # seasonal weight 0..1
      lam <- P$base * sw * runif(1, 0.6, 1.5)
      if (lam < 0.4) next                                    # a real zero-catch occasion
      k <- min(length(P$pool), 1 + rpois(1, lam = 1.6 * sw + 0.4))
      pick <- sample(seq_along(P$pool), k, prob = pool_w)
      # rare QC-flag injections (so the demo shows the clickable flags)
      bad_th  <- runif(1) < 0.012; day_bout <- runif(1) < 0.02
      bad_tgt <- runif(1) < 0.012; bad_cond <- runif(1) < 0.02
      for (pi in pick) {
        sci <- P$pool[pi]; tr <- tx_row(sci)
        ef <- if (runif(1) < 0.04) round(runif(1, 11, 22), 1) else round(runif(1, 1, 6), 1)
        tw <- round(runif(1, 2, 9), 2); sw2 <- round(tw / ef, 3)
        cnt <- max(1, round(rpois(1, lambda = max(0.5, lam / k)) * ef))
        femsh <- if (tr$genus == "Anopheles") 0.85 else 0.93
        nF <- round(cnt * femsh); nM <- cnt - nF
        mkrow <- function(sex, cc, target = TRUE, iq = "") {
          r <<- r + 1L
          data.frame(sampleID = sid, trapkey = traps_meta$trapkey[ti], plotID = traps_meta$plotID[ti],
            trapID = traps_meta$trapID[ti], year = yr, collectDate = cdate, week = wk,
            taxonID = NA_character_, scientificName = sci, vernacularName = tr$vernacular,
            taxonRank = if (nzchar(iq)) "genus" else "species", is_species = !nzchar(iq),
            genus = tr$genus, sex = sex, nativeStatusCode = "N", count = cc, is_target = target,
            nightOrDay = if (day_bout) "day" else "night",
            trapHours = if (bad_th) 0 else round(th, 1),
            targetTaxaPresent = if (bad_tgt) "N" else "Y",
            sampleCondition = if (bad_cond) "sample compromised in transit" else CLEAN,
            subsampleWeight = sw2, totalWeight = tw, expansionFactor = ef,
            identificationQualifier = iq, stringsAsFactors = FALSE)
        }
        if (nF > 0) obs_rows[[length(obs_rows) + 1L]] <- mkrow("F", nF)
        if (nM > 0) obs_rows[[length(obs_rows) + 1L]] <- mkrow("M", nM)
        bad_th <- day_bout <- bad_tgt <- bad_cond <- FALSE   # at most one flag per occasion
      }
      # rare bycatch + uncertain-ID rows for transparency
      if (runif(1) < 0.03) { r <- r + 1L; obs_rows[[length(obs_rows)+1L]] <- data.frame(
        sampleID=sid, trapkey=traps_meta$trapkey[ti], plotID=traps_meta$plotID[ti], trapID=traps_meta$trapID[ti],
        year=yr, collectDate=cdate, week=wk, taxonID=NA_character_, scientificName="Chironomidae sp.",
        vernacularName="non-biting midge", taxonRank="family", is_species=FALSE, genus="other", sex="U",
        nativeStatusCode="N", count=round(runif(1,1,8)), is_target=FALSE, nightOrDay="night",
        trapHours=round(th,1), targetTaxaPresent="Y", sampleCondition=CLEAN, subsampleWeight=NA_real_,
        totalWeight=NA_real_, expansionFactor=1, identificationQualifier="", stringsAsFactors=FALSE) }
    }
  }
  obs <- do.call(rbind, obs_rows)
  occ_df <- do.call(rbind, occ_rows)        # one row per ATTEMPTED occasion (incl. zero-catch)
  # per-(year,week) effort, the pulse denominator (all attempted trap-nights that week)
  effort_week <- stats::aggregate(trap_nights ~ year + week, data = occ_df, FUN = sum)
  # per-trap effort table, from ATTEMPTED occasions (element-wise, no fragile %||%)
  tk <- factor(occ_df$trapkey, levels = traps_meta$trapkey)
  traps <- data.frame(
    trapkey = traps_meta$trapkey, plotID = traps_meta$plotID, trapID = traps_meta$trapID,
    nlcdClass = traps_meta$nlcdClass, lat = traps_meta$lat, lng = traps_meta$lng,
    collectDate = as.Date(paste0(max(YEARS), "-07-15")),
    trap_nights = round(as.numeric(tapply(occ_df$trap_nights, tk, sum)), 2),
    n_collections = as.integer(table(tk)),
    stringsAsFactors = FALSE)
  traps$trap_nights[is.na(traps$trap_nights)] <- 0
  meta <- list(site = s, lat = mr$lat, lng = mr$lng, years = YEARS,
               trap_nights = round(occ_tn, 1), n_occ_attempted = occ_n,
               n_traps = ntr, synthetic = TRUE)
  list(obs = obs, traps = traps, effort_week = effort_week, meta = meta)
}

# ---- base-R incidence helpers for the cross-site precompute ---------------
rarefy_inc <- function(Y, T, t) { if (is.na(t) || t < 1 || t > T) return(NA_real_)
  round(sum(ifelse(T - Y < t, 1, 1 - exp(lchoose(T - Y, t) - lchoose(T, t)))), 1) }
coverage_inc <- function(Y, T) { U <- sum(Y); if (U == 0 || T < 2) return(NA_real_)
  Q1 <- sum(Y == 1); Q2 <- sum(Y == 2); round(1 - (Q1 / U) * ((T - 1) * Q1 / ((T - 1) * Q1 + 2 * max(Q2, 1))), 3) }
hill_inc <- function(Y) { p <- Y / sum(Y); p <- p[p > 0]; c(q1 = round(exp(-sum(p * log(p))), 1), q2 = round(1 / sum(p^2), 1)) }

idx <- list(); inc <- list(); clim <- list(); mclim <- list()
sites <- neon_sites$site
for (s in sites) {
  b <- mk_site(s); saveRDS(b, file.path("data/sites", paste0(s, ".rds")), compress = "xz")
  if (s == "SRER") saveRDS(b, "data-sample/demo.rds", compress = "xz")
  o <- b$obs; tg <- o[o$is_target %in% TRUE & o$is_species %in% TRUE, ]
  sp_tot <- tapply(tg$count, tg$scientificName, sum); top <- names(sp_tot)[which.max(sp_tot)]
  topg <- tx_row(top)$genus
  tn <- b$meta$trap_nights; nocc <- b$meta$n_occ_attempted   # ATTEMPTED occasions = honest denominator
  idx[[s]] <- data.frame(site = s, taxa = length(unique(tg$scientificName)),
    individuals = round(sum(tg$count)), collections = nocc,
    trap_nights = tn, mos_per_tn = round(sum(tg$count) / max(1, tn), 2),
    top_taxon = top, top_genus = topg, lat = b$meta$lat, lng = b$meta$lng,
    year_min = min(YEARS), year_max = max(YEARS), synthetic = TRUE, stringsAsFactors = FALSE)
  # incidence on collection occasions (T = attempted, incl. zero-catch)
  Y <- tapply(tg$sampleID, tg$scientificName, function(x) length(unique(x)))
  inc[[s]] <- list(Y = as.integer(Y), T = nocc,
                   pct_culex = round(100 * sum(tg$count[tg$genus == "Culex"]) / max(1, sum(tg$count)), 1),
                   mean_ubi = round(mean(100 * as.integer(Y) / max(1L, nocc)), 1))
  # ---- synthetic climate (monsoon-shaped) ----
  bm <- biome_of(s); P <- params(bm); mr <- neon_sites[neon_sites$site == s, ]
  mon <- 1:12
  tamp <- switch(bm, desert = 13, grassland = 14, forest = 12, tropical = 4, tundra = 16)
  tmean<- switch(bm, desert = 19, grassland = 11, forest = 10, tropical = 26, tundra = -6)
  temp_c <- round(tmean + tamp * sin(2 * pi * (mon - 4) / 12), 1)
  pbase  <- switch(bm, desert = 8, grassland = 55, forest = 80, tropical = 90, tundra = 12)
  monsoon<- ifelse(mon %in% 7:9, switch(bm, desert = 45, grassland = 30, tropical = 60, 12), 0)
  precip <- round(pbase + monsoon + rnorm(12, 0, 4), 0); precip[precip < 0] <- 0
  mclim[[s]] <- data.frame(site = s, mon = mon, temp_c = temp_c, precip_mm = precip, stringsAsFactors = FALSE)
  clim[[s]] <- data.frame(site = s, mat_c = round(mean(temp_c), 1),
    warm_temp_c = round(mean(temp_c[6:8]), 1), precip_annual_mm = sum(precip),
    monsoon_precip_mm = sum(precip[7:9]), has_gauge = P$gauge,
    monsoon_month_min = if (bm == "desert") 7L else if (bm %in% c("grassland","tropical")) 7L else NA_integer_,
    monsoon_month_max = if (bm == "desert") 9L else if (bm %in% c("grassland","tropical")) 9L else NA_integer_,
    stringsAsFactors = FALSE)
}
site_index <- do.call(rbind, idx)
site_index <- site_index[order(-site_index$mos_per_tn), ]
attr(site_index, "synthetic") <- TRUE
saveRDS(site_index, "data/site_index.rds", compress = "xz")
saveRDS(do.call(rbind, clim),  "data/site_climate.rds",   compress = "xz")
saveRDS(do.call(rbind, mclim), "data/site_month_clim.rds", compress = "xz")

# ---- cross_site.rds: rarefied richness + Hill + coverage + Culex share -----
t_common <- min(vapply(inc, function(x) as.integer(x$T), integer(1)))
cs <- do.call(rbind, lapply(names(inc), function(s) { x <- inc[[s]]; Y <- x$Y; T <- x$T; h <- hill_inc(Y)
  data.frame(site = s, T_occ = T, S_obs = length(Y), S_rare = rarefy_inc(Y, T, t_common), t_used = t_common,
    coverage = coverage_inc(Y, T), hill_q1 = unname(h["q1"]), hill_q2 = unname(h["q2"]),
    mean_ubiquity = x$mean_ubi, pct_culex = x$pct_culex, stringsAsFactors = FALSE) }))
attr(cs, "synthetic") <- TRUE
attr(cs, "method") <- sprintf("PLACEHOLDER (synthetic). Richness rarefied to %d collection occasions; Hill q1/q2 on incidence; coverage = Chao & Jost 2012.", t_common)
saveRDS(cs, "data/cross_site.rds", compress = "xz")

cat(sprintf("Wrote SYNTHETIC placeholder bundles for %d sites (t_common = %d). NOT real measurements.\n",
            nrow(site_index), t_common))
print(utils::head(site_index[, c("site","taxa","mos_per_tn","top_taxon","top_genus")], 8))
