suppressWarnings(suppressMessages(library(dplyr)))
source("R/mos_helpers.R")
b <- readRDS("data/sites/SRER.rds"); o <- b$obs

vb_all <- vector_board(o)
o_night <- o[tolower(as.character(o$nightOrDay)) %in% "night", , drop = FALSE]
vb_night <- vector_board(o_night)

cat("SRER site total whole-trap catch (ALL bouts) =", round(sum(vb_all$total), 1), "\n")
cat("SRER site total whole-trap catch (NIGHT only) =", round(sum(vb_night$total), 1), "\n")
cat("=> day bouts contribute", round(100 * (sum(vb_all$total) - sum(vb_night$total)) / sum(vb_all$total), 1),
    "% of the SRER catch that feeds the index\n")

# pulse phenology: do day-collection rows feed the weekly pulse? show weeks where day catch is nonzero
ef <- b$effort_week
pp_all <- pulse_phenology(o, ef)
cat("\npulse weeks (all):", nrow(pp_all), "\n")

# How many sites have day catch as a MATERIAL share (>5%) of total catch?
sites <- list.files("data/sites", pattern = "\\.rds$", full.names = TRUE)
mat <- 0; checked <- 0
for (f in sites) {
  bb <- readRDS(f); oo <- bb$obs
  if (is.null(oo) || !nrow(oo) || !("nightOrDay" %in% names(oo))) next
  va <- tryCatch(vector_board(oo), error = function(e) NULL)
  on <- oo[tolower(as.character(oo$nightOrDay)) %in% "night", , drop = FALSE]
  vn <- if (nrow(on)) tryCatch(vector_board(on), error = function(e) NULL) else NULL
  if (is.null(va)) next
  checked <- checked + 1
  ta <- sum(va$total); tn <- if (!is.null(vn)) sum(vn$total) else 0
  if (ta > 0 && (ta - tn) / ta > 0.05) mat <- mat + 1
}
cat("\nsites checked:", checked, "| sites where day bouts are >5% of index catch:", mat, "\n")
