#!/usr/bin/env Rscript
suppressWarnings(suppressMessages({
  library(shiny)
}))

Sys.setenv(MOS_LIVE = "0")
source("global.R", local = FALSE)
source("ui.R", local = FALSE)
source("server.R", local = FALSE)

fail <- function(message) stop("SERVER RUNTIME TEST FAILED: ", message, call. = FALSE)
expect <- function(condition, message) if (!isTRUE(condition)) fail(message)

# Exercise the same real-bundle path used after a visitor chooses a site. Source
# tests alone cannot catch render-time errors in Shiny outputs.
shiny::testServer(server, {
  # Before a site is chosen these outputs must suspend quietly. A regular R
  # error here is rendered by Shiny as the generic production error panel.
  hero_before <- tryCatch(output$heroStats, error = identity)
  insight_before <- tryCatch(output$siteInsights, error = identity)
  expect(inherits(hero_before, "shiny.silent.error"),
         "the pre-load hero must suspend without a visible error")
  expect(inherits(insight_before, "shiny.silent.error"),
         "the pre-load insights must suspend without a visible error")
})

# Use a fresh session for the loaded-state assertions. testServer keeps outputs
# it has read suspended as hidden, whereas the browser reveals these outputs when
# ingest() opens mainTabsWrap.
shiny::testServer(server, {
  load_site("SRER")

  hero_html <- output$heroStats$html
  insight_html <- output$siteInsights$html

  expect(grepl("hero-band", hero_html, fixed = TRUE),
         "the loaded-site hero statistics must render")
  expect(grepl("insight-list", insight_html, fixed = TRUE),
         "the loaded-site insight list must render")
  expect(grepl("hero-site", hero_html, fixed = TRUE), "the site name must render as the page heading")
  expect(grepl("week", output$pulseInsight$html, fixed = TRUE), "the pulse headline must name a peak week")
  expect(grepl("site-qc-tbl", output$siteQcCard$html, fixed = TRUE), "the site data-quality card must render")
  expect(grepl("codebookCsvAbout", output$aboutPanel$html, fixed = TRUE) &&
           grepl("Response Atlas", output$aboutPanel$html, fixed = TRUE), "About must carry the codebook and the suite registry")
  expect(nzchar(output$chaoBanner$html), "the Chao2 banner must render")
  pdf <- output$reportPdf
  expect(file.exists(pdf) && identical(readBin(pdf, "raw", 4), charToRaw("%PDF")), "the site report must download as a PDF")
  session$setInputs(spSel = "Psorophora columbiae")
  expect(identical(rv$sp, "Psorophora columbiae"), "picking a species must open its profile")
  session$setInputs(spSel = "")
  expect(is.null(rv$sp), "clearing the species picker must clear the profile")
})

# Contract B: a site loaded from the map syncs the by-name selects.
shiny::testServer(server, {
  session$setInputs(stateSel = "AZ")
  session$setInputs(pickSite = "HARV")
  expect(identical(rv$site, "HARV"), "a map pick must load that site")
  expect(identical(rv$pendingSite, "HARV"), "a pick in another state must queue the site for the State observer")
  session$setInputs(pickSite = "../site_index")
  expect(identical(rv$site, "HARV"), "a non-roster pickSite value must never reach readRDS")
})

cat("OK: real bundled-site Shiny outputs rendered without error.\n")
