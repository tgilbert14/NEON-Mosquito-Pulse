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

# ---- pin terra to the last release before the GDAL-3.8 multidim code (1.8-54) ----
# terra >= 1.8-54 ships gdal_multidimensional.cpp using a GDAL 3.8 call unguarded in
# releases, so it FAILS to compile against Connect Cloud's GDAL 3.4.1. Connect compiles
# from source regardless of repo. 1.8-50 is the last release before 1.8-54: it compiles
# on 3.4.1 and still satisfies raster's terra (>= 1.8-5). terra/raster are install-only
# (leaflet -> raster -> terra; the app never calls terra) -> zero runtime impact. Also
# pin the repo to the RSPM jammy binary mirror for suite consistency. WITHOUT this, the
# monthly CI regen re-pins terra to the latest (>= 1.8-54) and re-breaks the deploy.
local({
  mm <- jsonlite::fromJSON("manifest.json", simplifyVector = FALSE)
  if (!is.null(mm$packages$terra)) {
    mm$packages$terra$description$Version <- "1.8-50"
    if (!is.null(mm$packages$terra$description$RemoteSha)) mm$packages$terra$description$RemoteSha <- "1.8-50"
    jsonlite::write_json(mm, "manifest.json", auto_unbox = TRUE, pretty = TRUE, null = "null")
  }
  mtxt <- readLines("manifest.json", warn = FALSE)
  mtxt <- gsub("https://cloud.r-project.org", "https://packagemanager.posit.co/cran/__linux__/jammy/latest", mtxt, fixed = TRUE)
  mtxt <- gsub("https://packagemanager.posit.co/cran/latest", "https://packagemanager.posit.co/cran/__linux__/jammy/latest", mtxt, fixed = TRUE)
  writeLines(mtxt, "manifest.json")
  cat("Pinned terra to 1.8-50 + RSPM jammy repo.\n")
})
