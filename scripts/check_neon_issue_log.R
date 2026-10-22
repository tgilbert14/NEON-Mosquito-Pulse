#!/usr/bin/env Rscript
# Report NEON issue-log entries for the pinned product that are newer than the
# pinned release. NEON can log a data problem (or resolve one) after a release
# is generated; this makes each such entry visible in the refresh run so a
# person can decide whether the app copy or the data need a reviewed change.
#
# Reads MOS_RELEASE from R/mos_release.R and the product's changeLogs from the
# public products endpoint (no token). It only reports: it exits 0 whether or
# not it finds entries, and a network failure is a warning, not a failure.
# Base R plus jsonlite only.

suppressPackageStartupMessages(library(jsonlite))

source("R/mos_release.R")
pinned_date <- as.Date(MOS_RELEASE$release_generated)
if (is.na(pinned_date)) stop("MOS_RELEASE$release_generated is not a date", call. = FALSE)
product <- MOS_RELEASE$product
url <- paste0("https://data.neonscience.org/api/v0/products/", product)

summary_file <- Sys.getenv("GITHUB_STEP_SUMMARY", "")
to_summary <- function(lines) {
  if (nzchar(summary_file)) cat(lines, file = summary_file, sep = "\n", append = TRUE)
}
one_line <- function(x) {
  if (length(x) == 0 || is.na(x[1])) return("")
  x <- gsub("[\r\n]+", " ", as.character(x))
  x <- gsub("%", "%25", x, fixed = TRUE)   # GitHub workflow-command escaping
  trimws(x)
}

options(timeout = 60)
body <- tryCatch(
  jsonlite::fromJSON(url, simplifyVector = TRUE),
  error = function(e) e
)
if (inherits(body, "error")) {
  cat(sprintf("::warning title=NEON issue log unreachable::%s: %s\n", url, one_line(conditionMessage(body))))
  to_summary(sprintf("NEON issue log: could not read %s, not checked this run.", url))
  quit(save = "no", status = 0)
}

logs <- body$data$changeLogs
if (is.null(logs) || !is.data.frame(logs) || nrow(logs) == 0) {
  cat(sprintf("NEON issue log: no entries for %s.\n", product))
  to_summary(sprintf("NEON issue log: no entries for %s.", product))
  quit(save = "no", status = 0)
}

as_day <- function(x) {
  if (is.null(x)) return(rep(as.Date(NA), nrow(logs)))
  as.Date(substr(as.character(x), 1, 10))
}
issued <- as_day(logs$issueDate)
resolved <- as_day(logs$resolvedDate)
newer <- (!is.na(issued) & issued > pinned_date) | (!is.na(resolved) & resolved > pinned_date)
hits <- logs[newer, , drop = FALSE]
fmt_day <- function(d) if (is.na(d)) "not given" else format(d)

header <- sprintf(
  "NEON issue log for %s: %d of %d entries dated after %s (%s generated).",
  product, nrow(hits), nrow(logs), format(pinned_date), MOS_RELEASE$release
)
cat(header, "\n", sep = "")

if (nrow(hits) == 0) {
  to_summary(header)
  quit(save = "no", status = 0)
}

block <- c("### NEON issue log after the pinned release", "", header, "")
for (i in seq_len(nrow(hits))) {
  h <- hits[i, , drop = FALSE]
  issue_day <- fmt_day(issued[newer][i])
  resolved_day <- fmt_day(resolved[newer][i])
  where <- one_line(if (is.null(h$locationAffected)) "" else h$locationAffected)
  text <- one_line(if (is.null(h$issue)) "" else h$issue)
  cat(sprintf(
    "::warning title=NEON issue log entry %s::issued %s, resolved %s, location %s: %s\n",
    one_line(h$id), issue_day, resolved_day, if (nzchar(where)) where else "not given", text
  ))
  block <- c(block, sprintf(
    "- Entry %s, issued %s, resolved %s, location %s: %s",
    one_line(h$id), issue_day, resolved_day, if (nzchar(where)) where else "not given", text
  ))
}
to_summary(block)
quit(save = "no", status = 0)
