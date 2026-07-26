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
  load_site("SRER")

  hero_html <- as.character(output$heroStats)
  insight_html <- as.character(output$siteInsights)

  expect(grepl("hero-band", hero_html, fixed = TRUE),
         "the loaded-site hero statistics must render")
  expect(grepl("insight-list", insight_html, fixed = TRUE),
         "the loaded-site insight list must render")
})

cat("OK: real bundled-site Shiny outputs rendered without error.\n")
