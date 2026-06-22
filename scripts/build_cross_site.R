# ===========================================================================
# build_cross_site.R — precompute data/cross_site.rds: the EFFORT-STANDARDIZED
# community metrics the "Across the continent" gradient tab reads. Raw richness
# is an effort artifact, so we rarefy every site's richness to a COMMON number
# of collection occasions (trap-nights) and also report coverage, Hill q1/q2,
# mean ubiquity, and the Culex (West Nile group) share of the catch.
#
# One row per site: site, T_occ, S_obs, S_rare, t_used, coverage, hill_q1,
# hill_q2, mean_ubiquity, pct_culex.  Run:  Rscript scripts/build_cross_site.R
# ===========================================================================
suppressMessages({ library(dplyr) })
source("R/mos_helpers.R")

files <- list.files("data/sites", pattern = "\\.rds$", full.names = TRUE)
if (!length(files)) stop("No site bundles in data/sites — run scripts/bundle_mos_data.R first.")

inc <- list(); base <- list()
for (f in files) {
  s <- sub("\\.rds$", "", basename(f))
  b <- tryCatch(readRDS(f), error = function(e) NULL); if (is.null(b) || is.null(b$obs)) next
  si <- site_incidence(b$obs, b$meta$n_occ_attempted); if (is.null(si) || si$T < 2) next
  inc[[s]] <- si
  brd <- vector_board(b$obs, b$meta$n_occ_attempted %||% si$T, b$meta$trap_nights)
  gs  <- genus_share(b$obs); culex <- if (!is.null(gs)) gs$share[gs$genus == "Culex"] else NA_real_
  base[[s]] <- data.frame(site = s, T_occ = si$T, S_obs = length(si$Y),
                          mean_ubiquity = round(mean(brd$ubiquity), 1),
                          pct_culex = if (length(culex) && !is.na(culex)) culex else 0)
}
t_common <- min(vapply(inc, function(x) x$T, integer(1)))
cat(sprintf("Common rarefaction target t = %d collection occasions (min over %d sites)\n", t_common, length(inc)))

rows <- lapply(names(inc), function(s) { Y <- inc[[s]]$Y; T <- inc[[s]]$T; h <- hill_incidence(Y)
  cbind(base[[s]], S_rare = rarefy_incidence(Y, T, t_common), t_used = t_common,
        coverage = round(coverage_incidence(Y, T), 3), hill_q1 = unname(h["q1"]), hill_q2 = unname(h["q2"])) })
cs <- dplyr::bind_rows(rows)
attr(cs, "method") <- sprintf("Richness rarefied to %d collection occasions (incidence rarefaction; Colwell et al. 2012). Hill q1/q2 on incidence; coverage = Chao & Jost 2012. Culex share = West Nile group %% of the whole-trap catch.", t_common)
saveRDS(cs, "data/cross_site.rds", compress = "xz")
cat(sprintf("cross_site.rds: %d sites | S_obs %d-%d, S_rare(@%d) %.0f-%.0f\n",
            nrow(cs), min(cs$S_obs), max(cs$S_obs), t_common, min(cs$S_rare, na.rm = TRUE), max(cs$S_rare, na.rm = TRUE)))
print(cs[order(-cs$S_rare), c("site","T_occ","S_obs","S_rare","coverage","pct_culex")], row.names = FALSE)
