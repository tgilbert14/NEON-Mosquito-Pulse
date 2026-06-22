setwd("C:/Users/tsgil/OneDrive/Documents/VGS - R/NEON-Mosquito-Pulse")
suppressWarnings(suppressMessages({ library(dplyr) }))
`%||%` <- function(a,b) if (is.null(a)) b else a
source("R/mos_helpers.R")

files <- list.files("data/sites", pattern="\\.rds$", full.names=TRUE)
info <- lapply(files, function(f){
  b <- readRDS(f); site <- sub("\\.rds$","", basename(f))
  obs <- b$obs
  nr <- if (is.data.frame(obs)) nrow(obs) else NA_integer_
  sp <- tryCatch(target_only(species_level_only(obs)), error=function(e) NULL)
  k_eff <- if (!is.null(sp) && !is.null(nrow(sp)) && nrow(sp)) length(unique(as.character(sp$sampleID))) else 0L
  data.frame(site=site, obs_rows=as.integer(nr), k_eff=as.integer(k_eff), stringsAsFactors=FALSE)
})
info <- do.call(rbind, info); info <- info[order(-info$k_eff),]
cat("=== Top sites by k_eff (collection occasions feeding mos_accum) ===\n")
print(head(info, 8), row.names=FALSE)
cat("\nMax obs_rows:", max(info$obs_rows, na.rm=TRUE), " | Max k_eff:", max(info$k_eff, na.rm=TRUE), "\n\n")

time_site <- function(s){
  b <- readRDS(file.path("data/sites", paste0(s, ".rds")))
  obs <- b$obs; traps <- b$traps
  ac <- mos_accum(obs, traps)            # warm
  reps <- 10
  t <- system.time(for (i in 1:reps) mos_accum(obs, traps))
  per <- 1000*t[["elapsed"]]/reps
  cat(sprintf("  %-6s k_eff=%-4d obs_rows=%-6d  -> %.1f ms/call  (accum rows=%s)\n",
    s, info$k_eff[info$site==s], info$obs_rows[info$site==s], per, if(is.null(ac)) "NULL" else nrow(ac)))
  invisible(per)
}
cat("=== Timing mos_accum (10 reps each) on the heaviest real-data sites ===\n")
for (s in head(info$site, 5)) time_site(s)
