sites <- list.files("data/sites", pattern = "\\.rds$", full.names = TRUE)
cat("n site bundles:", length(sites), "\n")
tot_obs <- 0; tot_day <- 0; tot_night <- 0; tot_other <- 0
sites_with_day <- 0; sites_with_nd_col <- 0; cols_seen <- NULL
for (f in sites) {
  b <- readRDS(f)
  o <- b$obs
  if (is.null(o) || !nrow(o)) next
  if (is.null(cols_seen)) cols_seen <- names(o)
  tot_obs <- tot_obs + nrow(o)
  if ("nightOrDay" %in% names(o)) {
    sites_with_nd_col <- sites_with_nd_col + 1
    nd <- tolower(as.character(o$nightOrDay))
    d <- sum(nd %in% "day"); n <- sum(nd %in% "night"); ot <- sum(!(nd %in% c("day", "night")))
    tot_day <- tot_day + d; tot_night <- tot_night + n; tot_other <- tot_other + ot
    if (d > 0) sites_with_day <- sites_with_day + 1
  }
}
cat("obs columns:", paste(cols_seen, collapse = ", "), "\n")
cat("sites with nightOrDay col:", sites_with_nd_col, "\n")
cat("total obs rows:", tot_obs, "\n")
cat("DAY rows:", tot_day, "| NIGHT rows:", tot_night, "| other/NA:", tot_other, "\n")
cat("sites with >=1 day-bout obs row:", sites_with_day, "\n")

# Decisive: does pulse_phenology / vector_board exclude day rows? They call
# target_only(species_level_only(obs)) which do NOT filter nightOrDay. Prove the
# day rows survive into the index input at one big site.
src_ok <- tryCatch({ source("R/mos_helpers.R"); TRUE }, error = function(e) { cat("source err:", conditionMessage(e), "\n"); FALSE })
if (src_ok) {
  b <- readRDS("data/sites/SRER.rds"); o <- b$obs
  inp <- target_only(species_level_only(o))
  nd_in <- tolower(as.character(inp$nightOrDay))
  cat("\nSRER: obs rows =", nrow(o),
      "| after target/species gate =", nrow(inp),
      "| day rows surviving into index input =", sum(nd_in %in% "day"),
      "| night =", sum(nd_in %in% "night"), "\n")
  # vector_board index uses sum(count)/trap_nights over ALL rows (incl day)
  vb_all <- vector_board(o)
  o_night <- o[tolower(as.character(o$nightOrDay)) %in% "night", , drop = FALSE]
  vb_night <- if (nrow(o_night)) vector_board(o_night) else NULL
  cat("SRER site index total (all bouts) =", round(sum(vb_all$total), 1),
      "| total if night-only =", if (!is.null(vb_night)) round(sum(vb_night$total), 1) else NA, "\n")
}
