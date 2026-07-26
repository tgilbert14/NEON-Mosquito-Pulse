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
})

cat("OK: real bundled-site Shiny outputs rendered without error.\n")
