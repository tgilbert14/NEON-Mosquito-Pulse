# ===========================================================================
# write_manifest.R — (re)generate manifest.json for Posit Connect Cloud.
#
# RUN THIS after ANY change to runtime dependencies or the committed data set,
# then COMMIT manifest.json — Connect Cloud reads the committed manifest, so a
# stale manifest restores the OLD package set or serves yesterday's data
# (the single-builder-precompute / "regenerate-or-stale" rule).
#
#   Rscript scripts/write_manifest.R
#
# neonUtilities is referenced only via a split string + requireNamespace in
# global.R, so rsconnect's static dependency scan does NOT pick it up — the
# deploy stays lean (the app runs off the committed bundles, never a live fetch).
# ===========================================================================
if (!requireNamespace("rsconnect", quietly = TRUE)) stop("install.packages('rsconnect') first")

rsconnect::writeManifest(
  appDir = ".",                   # ui.R + server.R + global.R -> detected as a Shiny app
  appFiles = c(
    "global.R", "ui.R", "server.R",
    list.files("R", full.names = TRUE),
    list.files("www", full.names = TRUE),
    list.files("data", recursive = TRUE, full.names = TRUE),
    list.files("data-sample", full.names = TRUE)
  )
)

m <- jsonlite::fromJSON("manifest.json")
pkgs <- names(m$packages)
cat(sprintf("manifest.json written: %d packages.\n", length(pkgs)))
if (any(grepl("neonUtilities", pkgs, ignore.case = TRUE))) {
  warning("neonUtilities leaked into the manifest — the deploy will be heavy. Check the global.R guard.")
} else {
  cat("Good: neonUtilities is NOT in the manifest (lean deploy).\n")
}
