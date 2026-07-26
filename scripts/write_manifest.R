#!/usr/bin/env Rscript
# Generate and gate a deterministic Connect manifest in the pinned validator.
suppressMessages({ library(rsconnect); library(jsonlite) })
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

snapshot <- "https://packagemanager.posit.co/cran/__linux__/jammy/2026-07-15"
platform <- "4.5.2"
runtime <- c("shiny", "bslib", "bsicons", "dplyr", "tidyr", "stringr", "tibble",
             "plotly", "leaflet", "DT", "shinyjs", "shinycssloaders", "RColorBrewer", "htmltools")
drop <- c("neonUtilities", "arrow")
geo <- c(terra="1.8-50", sf="1.1-1", s2="1.1.11", units="1.0-1", wk="0.9.5",
         classInt="0.4-11", raster="3.6-32", sp="2.2-1")
geo_urls <- c(
  terra="https://cran.r-project.org/src/contrib/Archive/terra/terra_1.8-50.tar.gz",
  sf="https://packagemanager.posit.co/cran/2026-07-15/src/contrib/sf_1.1-1.tar.gz",
  s2="https://packagemanager.posit.co/cran/2026-07-15/src/contrib/s2_1.1.11.tar.gz",
  units="https://packagemanager.posit.co/cran/2026-07-15/src/contrib/units_1.0-1.tar.gz",
  wk="https://packagemanager.posit.co/cran/2026-07-15/src/contrib/wk_0.9.5.tar.gz",
  classInt="https://packagemanager.posit.co/cran/2026-07-15/src/contrib/classInt_0.4-11.tar.gz",
  raster="https://packagemanager.posit.co/cran/2026-07-15/src/contrib/raster_3.6-32.tar.gz",
  sp="https://packagemanager.posit.co/cran/2026-07-15/src/contrib/sp_2.2-1.tar.gz")

app_files <- c("global.R", "ui.R", "server.R",
  list.files("R", pattern="[.]R$", full.names=TRUE),
  list.files("www", recursive=TRUE, full.names=TRUE),
  list.files("data", recursive=TRUE, full.names=TRUE),
  list.files("data-sample", recursive=TRUE, full.names=TRUE))
app_files <- sort(unique(app_files[file.exists(app_files) & !dir.exists(app_files)]))
rsconnect::writeManifest(appDir=".", appFiles=app_files)

manifest <- jsonlite::fromJSON("manifest.json", simplifyVector=FALSE)
packages <- manifest$packages
dependencies <- function(info) {
  description <- info$description
  if (is.null(description)) return(character(0))
  fields <- paste(c(description$Imports, description$Depends, description$LinkingTo), collapse=",")
  tokens <- trimws(unlist(strsplit(gsub("[\r\n]", " ", fields), ",")))
  tokens <- trimws(sub("[ (].*$", "", tokens))
  intersect(tokens[nzchar(tokens) & tokens != "R"], names(packages))
}
reachable <- character(0)
frontier <- setdiff(intersect(runtime, names(packages)), drop)
while (length(frontier)) {
  reachable <- union(reachable, frontier)
  frontier <- setdiff(unique(unlist(lapply(frontier, function(pkg) dependencies(packages[[pkg]])))),
                      c(reachable, drop))
}
missing_roots <- setdiff(runtime, reachable)
if (length(missing_roots)) stop("manifest missing runtime roots: ", paste(missing_roots, collapse=", "))
manifest$packages <- packages[reachable]
jsonlite::write_json(manifest, "manifest.json", auto_unbox=TRUE, pretty=TRUE, null="null")

text <- readLines("manifest.json", warn=FALSE)
for (moving in c("https://packagemanager.posit.co/cran/latest",
                 "https://packagemanager.posit.co/cran/__linux__/jammy/latest",
                 "https://cloud.r-project.org")) text <- gsub(moving, snapshot, text, fixed=TRUE)
writeLines(text, "manifest.json")
canonical <- jsonlite::fromJSON("manifest.json", simplifyVector=FALSE)
for (pkg in names(geo)) if (!is.null(canonical$packages[[pkg]]$description)) {
  canonical$packages[[pkg]]$description$Built <- NULL
  canonical$packages[[pkg]]$Source <- "CRAN"
  canonical$packages[[pkg]]$Repository <- "https://cran.r-project.org"
}
jsonlite::write_json(canonical, "manifest.json", auto_unbox=TRUE, pretty=TRUE, null="null")

check <- jsonlite::fromJSON("manifest.json", simplifyVector=FALSE)
problems <- character(0)
if (!identical(as.character(check$platform %||% ""), platform)) problems <- c(problems, "wrong R platform")
keys <- names(check$packages)
if (length(intersect(drop, keys))) problems <- c(problems, "build-only package leaked into manifest")
for (pkg in keys) {
  item <- check$packages[[pkg]]
  version <- as.character(item$description$Version %||% "")
  if (!identical(as.character(item$description$Package %||% ""), pkg) || !nzchar(version) ||
      !identical(as.character(item$Source %||% ""), "CRAN")) problems <- c(problems, paste("invalid identity", pkg))
  if (pkg %in% names(geo)) {
    expected_ref <- paste0("url::", unname(geo_urls[[pkg]]))
    if (!identical(version, unname(geo[[pkg]])) ||
        !identical(as.character(item$Repository %||% ""), "https://cran.r-project.org") ||
        !identical(as.character(item$description$RemotePkgRef %||% ""), expected_ref) ||
        nzchar(as.character(item$description$Built %||% ""))) problems <- c(problems, paste("invalid geo pin", pkg))
  } else if (!identical(as.character(item$Repository %||% ""), snapshot)) problems <- c(problems, paste("moving repository", pkg))
}
if (length(setdiff(names(geo), keys))) problems <- c(problems, "missing geospatial closure")
if (length(problems)) stop("MANIFEST GATE FAILED: ", paste(unique(problems), collapse="; "), call.=FALSE)
cat(sprintf("OK: manifest has %d runtime files and %d pinned packages.\n", length(check$files), length(keys)))
