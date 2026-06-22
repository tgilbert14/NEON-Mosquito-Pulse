# ===========================================================================
# build_climate.R — precompute the REAL climate tables from the shared NEON
# environmental overlays (data/env/<SITE>.rds: monthly precip + air temperature,
# the SAME overlays the other suite apps carry). Replaces the synthetic climate
# the preview builder wrote. Run AFTER copying data/env/*.rds in (they are shared
# across the suite — identical sites, identical NEON source).
#
# Writes:
#   data/site_climate.rds    — ONE row per site: site, lat, lng, mat_c (mean
#     annual air temp), warm_temp_c (Jun–Aug mean), precip_annual_mm + the
#     warm-season monsoon_precip_mm (NA where NEON has no gauge), has_gauge,
#     and a DATA-DRIVEN monsoon window monsoon_month_min/max (the warm-season
#     months whose precip climatology beats the annual monthly mean; NA where
#     there is no summer peak, e.g. winter-rain Mediterranean sites).
#   data/site_month_clim.rds — site x month (1–12) climatology: temp_c, precip_mm.
#
# DEFENSIVE: precip is present at only ~19/46 sites, so the monsoon band only
# draws where a real gauge + a real summer peak exist — never imputed. Honest.
#   Rscript scripts/build_climate.R
# ===========================================================================
suppressMessages({ library(dplyr); library(tibble) })
source("R/site_metadata.R")

ENV_DIR <- "data/env"
env_files <- list.files(ENV_DIR, pattern = "\\.rds$", full.names = TRUE)
if (!length(env_files)) stop("No env files in ", ENV_DIR, " — copy data/env/<SITE>.rds first.")

clim_rows <- list(); month_rows <- list()
for (f in env_files) {
  s <- sub("\\.rds$", "", basename(f))
  e <- tryCatch(tibble::as_tibble(readRDS(f)), error = function(ee) NULL)
  if (is.null(e) || !nrow(e) || !all(c("ym","temp_c","precip_mm") %in% names(e))) next
  e$mon <- suppressWarnings(as.integer(substr(e$ym, 6, 7)))
  e$yr  <- substr(e$ym, 1, 4)

  # monthly climatology (mean across years; NA where <2 obs), arranged mon 1..12
  mc <- e %>% group_by(mon) %>% summarise(
      temp_c    = if (sum(!is.na(temp_c))    >= 2) mean(temp_c,    na.rm = TRUE) else NA_real_,
      precip_mm = if (sum(!is.na(precip_mm)) >= 2) mean(precip_mm, na.rm = TRUE) else NA_real_,
      .groups = "drop") %>%
    right_join(tibble(mon = 1:12), by = "mon") %>% arrange(mon)
  mc$site <- s
  month_rows[[s]] <- mc[, c("site", "mon", "temp_c", "precip_mm")]

  mat <- round(mean(e$temp_c, na.rm = TRUE), 1)
  warm_temp <- if (any(!is.na(mc$temp_c[6:8]))) round(mean(mc$temp_c[6:8], na.rm = TRUE), 1) else mat

  # precip / gauge: a "gauge" = >=6 months of any precip data
  n_precip  <- sum(!is.na(e$precip_mm)); has_gauge <- n_precip >= 6
  pr_by_yr  <- e %>% group_by(yr) %>% summarise(n = sum(!is.na(precip_mm)),
                  tot = sum(precip_mm, na.rm = TRUE), .groups = "drop") %>% filter(n >= 6)
  precip_annual  <- if (has_gauge && nrow(pr_by_yr)) round(mean(pr_by_yr$tot)) else NA_real_
  monsoon_precip <- if (has_gauge && any(!is.na(mc$precip_mm[6:9]))) round(sum(mc$precip_mm[6:9], na.rm = TRUE)) else NA_real_

  # DATA-DRIVEN monsoon window: warm-season (Jun–Oct) months whose precip
  # climatology beats the annual monthly mean. >=2 such months = a real summer
  # peak; otherwise NA (winter-rain / aseasonal site -> no band drawn).
  mm_min <- NA_integer_; mm_max <- NA_integer_
  if (has_gauge && any(!is.na(mc$precip_mm))) {
    avg <- mean(mc$precip_mm, na.rm = TRUE); warm <- 6:10; pw <- mc$precip_mm[warm]
    wet <- warm[!is.na(pw) & pw > avg]
    if (length(wet) >= 2) { mm_min <- min(wet); mm_max <- max(wet) }
  }

  meta <- neon_sites[neon_sites$site == s, ]
  clim_rows[[s]] <- tibble(
    site = s,
    lat = if (nrow(meta)) meta$lat[1] else NA_real_,
    lng = if (nrow(meta)) meta$lng[1] else NA_real_,
    mat_c = mat, warm_temp_c = warm_temp,
    precip_annual_mm = precip_annual, monsoon_precip_mm = monsoon_precip,
    has_gauge = has_gauge, monsoon_month_min = mm_min, monsoon_month_max = mm_max,
    env_year_min = suppressWarnings(min(as.integer(e$yr), na.rm = TRUE)),
    env_year_max = suppressWarnings(max(as.integer(e$yr), na.rm = TRUE)))
}

clim  <- bind_rows(clim_rows)
mclim <- bind_rows(month_rows)
saveRDS(clim,  "data/site_climate.rds",    compress = "xz")
saveRDS(mclim, "data/site_month_clim.rds", compress = "xz")

cat(sprintf("site_climate.rds: %d sites | temp %d/%d, precip gauge %d, monsoon window %d\n",
            nrow(clim), sum(!is.na(clim$mat_c)), nrow(clim),
            sum(clim$has_gauge), sum(!is.na(clim$monsoon_month_min))))
print(clim[order(clim$mat_c), c("site","mat_c","warm_temp_c","precip_annual_mm","monsoon_precip_mm","has_gauge","monsoon_month_min","monsoon_month_max")], n = nrow(clim))
