# ===========================================================================
# NEON Mosquito Pulse — global.R
# A NEONize sibling (Desert Data Labs) for Mosquitoes sampled from CO2 traps
# (DP1.10043.001). Chrome + bundling spine + pin-card interaction ported from
# the prior siblings; the analysis layer is CO2-trap / activity-index native.
#
# Honesty grain: abundance is a WITHIN-SITE activity index (mosquitoes per
# trap-night), never a population. CO2 traps lure host-seeking females, so the
# catch is a measure of host-seeking activity, not a headcount.
# ===========================================================================
suppressPackageStartupMessages({
  library(shiny); library(bslib); library(bsicons)
  library(dplyr); library(tidyr); library(stringr); library(tibble)
  library(plotly); library(leaflet); library(DT)
  library(shinyjs); library(shinycssloaders); library(RColorBrewer); library(htmltools)
})
source("R/site_metadata.R", local = FALSE)
source("R/mos_helpers.R",   local = FALSE)

NEON_DPID <- "DP1.10043.001"   # Mosquitoes sampled from CO2 traps
.NEON_PKG <- paste0("neon", "Utilities")
LIVE_FETCH <- (Sys.getenv("MOS_LIVE", "0") != "0") && requireNamespace(.NEON_PKG, quietly = TRUE)

SITE_DIR  <- "data/sites"
DEMO_PATH <- "data-sample/demo.rds"
DEMO_META <- list(site = "SRER", label = "SRER · Santa Rita · demo")

read_bundle <- function(f) {
  if (!file.exists(f)) return(NULL)
  out <- tryCatch(readRDS(f), error = function(e) { warning(sprintf("read_bundle('%s'): %s", f, conditionMessage(e))); NULL })
  if (is.null(out)) return(NULL)
  if (is.data.frame(out)) return(out)
  if (is.null(out$obs) || !nrow(out$obs)) NULL else out
}
load_site_bundle <- function(site) read_bundle(file.path(SITE_DIR, paste0(site, ".rds")))
load_demo <- function() { b <- load_site_bundle(DEMO_META$site); if (!is.null(b)) b else read_bundle(DEMO_PATH) }

SITE_INDEX <- tryCatch(readRDS("data/site_index.rds"), error = function(e) NULL)
BUNDLED <- if (!is.null(SITE_INDEX)) SITE_INDEX$site else character(0)
site_table <- if (length(BUNDLED)) {
  m <- neon_sites[match(BUNDLED, neon_sites$site), ]
  cbind(m, SITE_INDEX[match(m$site, SITE_INDEX$site),
    intersect(c("taxa", "individuals", "collections", "trap_nights", "mos_per_tn", "top_taxon", "top_genus", "synthetic"), names(SITE_INDEX))])
} else neon_sites[0, ]

# Data-state flags drive the honest banners. NO_DATA: nothing bundled yet (the
# app boots, but there are no sites to pick) -> show a "build the data" banner.
# ANY_SYNTHETIC: placeholder catches loaded -> show a "preview build" banner.
NO_DATA <- is.null(SITE_INDEX) || !length(BUNDLED) || !nrow(site_table)
ANY_SYNTHETIC <- !NO_DATA && (isTRUE(any(SITE_INDEX$synthetic %in% TRUE)) || isTRUE(attr(SITE_INDEX, "synthetic")))

mos_state_choices <- function() {
  st <- sort(unique(site_table$state)); if (!length(st)) return(NULL)
  setNames(st, sprintf("%s (%d)", state_names[st] %||% st, as.integer(table(site_table$state)[st])))
}
mos_sites_in_state <- function(stt) {
  rows <- site_table[site_table$state == stt, ]; rows <- rows[order(rows$name), ]
  if (!nrow(rows)) return(character(0))
  setNames(rows$site, sprintf("%s · %s", rows$site, rows$name))
}

# ---------------------------------------------------------------------------
# "Monsoon Nightstorm" palette (Vera). Storm-violet night + an electric swarm
# lime + a monsoon-amber RESERVED for the West Nile / Culex vector note. OLD key
# names are kept and remapped so shared code paths (server.R's DDL$sky etc.) keep
# working. The genus + sex DATA palettes below are LOCKED — they are data, not
# theme, and are never aliased to a CSS token.
# ---------------------------------------------------------------------------
DDL <- list(
  paper = "#fbfaff", bg = "#f3f1fa",
  ink = "#221d36", ink2 = "#463d63", muted = "#6f6790", line = "#ddd6ee",
  violet = "#7c52e0", violet2 = "#5e39c4", lime = "#5f9e12", lime_ink = "#4a7d0e",
  amber = "#e8920f", amber_ink = "#9a5f08",
  # legacy aliases -> nightstorm, so shared code paths stay on-theme
  navy = "#2a2342", navy2 = "#4b3d78", cardinal = "#7c52e0",
  gold = "#e8920f", gold2 = "#9a5f08", sky = "#3fb6c9",
  green = "#5f9e12", green2 = "#4a7d0e", terra = "#7c52e0", rust = "#7c52e0")

# ---- LOCKED DATA palettes (data, never theme; never read from var(--…)) ----
# Mosquito genera — fixed legend order; Culex leads (the West Nile vector).
GENUS_COL <- c(Culex = "#e8920f", Aedes = "#7c52e0", Anopheles = "#3fb6c9",
               Culiseta = "#5f9e12", Psorophora = "#d94f7a", Coquillettidia = "#8a6fb0",
               other = "#8a8fa3")
genus_col <- function(g) { out <- unname(GENUS_COL[g]); ifelse(is.na(out), unname(GENUS_COL["other"]), out) }
# Sex — fixed order female -> male -> undetermined. CO2 traps catch mostly
# host-seeking females, so female owns the brand-violet; "U" is always grey.
SEX_COL <- c(F = "#7c52e0", M = "#3fb6c9", U = "#9aa0b4")
sex_col <- function(s) { s <- toupper(substr(as.character(s), 1, 1)); out <- unname(SEX_COL[s]); ifelse(is.na(out), unname(SEX_COL["U"]), out) }
sex_lab <- c(F = "Female", M = "Male", U = "Undetermined")

app_theme <- bs_theme(version = 5, bg = "#fbfaff", fg = DDL$ink,
  primary = DDL$violet, secondary = DDL$amber, success = DDL$lime, info = DDL$sky,
  warning = DDL$amber, danger = "#d94f7a",
  base_font = font_google("Rubik"), heading_font = font_google("Rubik"), "border-radius" = "10px")

asset_url <- function(path) { f <- file.path("www", path)
  v <- if (file.exists(f)) as.integer(as.numeric(file.mtime(f))) else 0L; sprintf("%s?v=%s", path, v) }
spin <- function(x, img = NULL) shinycssloaders::withSpinner(x, color = DDL$violet, type = 6)
info_pop <- function(title, ..., placement = "auto")
  bslib::popover(tags$span(class = "info-dot", bsicons::bs_icon("info-circle")), ..., title = title, placement = placement)
insight_banner <- function(icon, ..., tone = "navy")
  div(class = paste("chart-insight", paste0("ci-", tone)), bsicons::bs_icon(icon), div(class = "ci-text", ...))
glow_badge <- function(label, color = "#7c52e0", glow = color)
  span(class = "glow-badge", style = sprintf("color:#fff; background:%s; border-color:%s;", color, color), label)
card_head <- function(icon, title, ...)
  bslib::card_header(class = "with-info", bsicons::bs_icon(icon), tags$span(class = "ch-title", " ", title), ...)
fmt_int <- function(x) format(round(as.numeric(x)), big.mark = ",", trim = TRUE)

# temperature display — Fahrenheit (default, US audience) or Celsius. Stored data
# is always °C; these convert for display only. (Spearman/rank stats are unit-free.)
temp_val  <- function(c, unit = "F") if (identical(unit, "C")) c else c * 9 / 5 + 32
temp_unit_lab <- function(unit = "F") if (identical(unit, "C")) "°C" else "°F"
temp_disp <- function(c, unit = "F") {
  c <- suppressWarnings(as.numeric(c))
  s <- if (identical(unit, "C")) sprintf("%.1f°C", c) else sprintf("%.0f°F", c * 9 / 5 + 32)
  s[is.na(c)] <- "—"; s
}

# ---- biome classification (cross-site gradient color / legend) --------------
SITE_BIOME <- c(
  BARR="tundra", TOOL="tundra", NIWO="tundra",
  JORN="desert", SRER="desert", MOAB="desert", ONAQ="desert",
  WOOD="grassland", DCFS="grassland", NOGP="grassland", KONZ="grassland", KONA="grassland",
  CPER="grassland", STER="grassland", OAES="grassland", CLBJ="grassland", YELL="grassland", SJER="grassland",
  GUAN="tropical", LAJA="tropical")
biome_of  <- function(site) { b <- unname(SITE_BIOME[site]); ifelse(is.na(b), "forest", b) }
BIOME_COL <- c(forest="#2f7f4f", grassland="#e8a317", desert="#c1502e", tundra="#7fa8c9", tropical="#9c5fb0")
BIOME_LAB <- c(forest="Forest", grassland="Grassland / prairie", desert="Desert / shrub",
               tundra="Tundra / alpine", tropical="Tropical dry forest")
biome_col <- function(b) { out <- unname(BIOME_COL[b]); ifelse(is.na(out), "#9aa6b2", out) }

# Precip regime from the site's REAL climatology (data/site_climate.rds), NOT the
# biome label — so the pulse band + prose don't call a winter-rain Great-Basin site
# (ONAQ) or an Alaskan forest a "monsoon". Returns:
#   "monsoon"     — a real summer-DOMINANT rain peak (>=40% of annual in the window)
#   "summer_rain" — a warm-season rain bump, but not summer-dominant
#   "none"        — no gauge, or no summer rain peak at all
precip_regime <- function(cl) {
  if (is.null(cl) || !nrow(cl) || !isTRUE(cl$has_gauge[1]) ||
      !"monsoon_month_min" %in% names(cl) || is.na(cl$monsoon_month_min[1])) return("none")
  sh <- if (!is.na(cl$monsoon_precip_mm[1]) && !is.na(cl$precip_annual_mm[1]) && cl$precip_annual_mm[1] > 0)
          cl$monsoon_precip_mm[1] / cl$precip_annual_mm[1] else NA_real_
  if (!is.na(sh) && sh >= 0.40) "monsoon" else "summer_rain"
}

# ---- precomputed climate / cross-site tables (built by scripts/, loaded once) -
SITE_CLIMATE    <- tryCatch(readRDS("data/site_climate.rds"),    error = function(e) NULL)
SITE_MONTH_CLIM <- tryCatch(readRDS("data/site_month_clim.rds"), error = function(e) NULL)
CROSS_SITE      <- tryCatch(readRDS("data/cross_site.rds"),      error = function(e) NULL)

# One row per site for the "Across the continent" tab: climate + community
# metrics + biome, joined once at boot. NULL-safe so a missing precompute
# degrades the tab, never crashes boot.
GRADIENT <- local({
  if (is.null(SITE_CLIMATE) || is.null(SITE_INDEX)) return(NULL)
  keep <- intersect(c("site","taxa","individuals","collections","trap_nights","mos_per_tn","top_taxon","top_genus"), names(SITE_INDEX))
  g <- merge(SITE_CLIMATE, SITE_INDEX[, keep], by = "site", all.x = TRUE)
  if (!is.null(CROSS_SITE)) g <- merge(g, CROSS_SITE, by = "site", all.x = TRUE)
  m <- neon_sites[match(g$site, neon_sites$site), ]
  g$name <- m$name; g$state <- m$state; g$bio <- m$bio
  g$biome <- biome_of(g$site); g$biome_col <- biome_col(g$biome); g$biome_lab <- unname(BIOME_LAB[g$biome])
  g[order(g$mat_c %||% g$site), ]
})

# ---------------------------------------------------------------------------
# The app mascot — "Skeeter," a flat (no-gradient, no-id so it's safely
# reusable) cheerful round mosquito in the nightstorm accent. Used as the
# loading spinner, the splash guide, and the celebration hop. Wing paddles are
# classed mascot-ear-l/r so the CSS can flap them; eyes blink via mascot-eyes.
# ---------------------------------------------------------------------------
MASCOT_CRITTER <- htmltools::HTML(paste0(
  '<svg class="mascot" viewBox="0 0 120 120" aria-hidden="true">',
  # antennae
  '<g stroke="#b8f24a" stroke-width="3.2" stroke-linecap="round" fill="none">',
  '<path d="M52,40 Q46,26 50,18"/><path d="M68,40 Q74,26 70,18"/>',
  '<circle cx="50" cy="18" r="2.6" fill="#d6ff7a" stroke="none"/><circle cx="70" cy="18" r="2.6" fill="#d6ff7a" stroke="none"/></g>',
  # wings (the flap-able "ears")
  '<g class="mascot-ear-l"><path d="M34,54 Q14,52 18,76 Q40,74 48,60 Z" fill="#b8f24a" fill-opacity=".9"/></g>',
  '<g class="mascot-ear-r"><path d="M86,54 Q106,52 102,76 Q80,74 72,60 Z" fill="#b8f24a" fill-opacity=".9"/></g>',
  # legs
  '<g stroke="#6f4ad0" stroke-width="2.6" stroke-linecap="round" fill="none">',
  '<path d="M48,92 q-16,10 -28,8"/><path d="M50,98 q-14,16 -28,18"/>',
  '<path d="M72,92 q16,10 28,8"/><path d="M70,98 q14,16 28,18"/></g>',
  # body + belly
  '<ellipse cx="60" cy="66" rx="30" ry="33" fill="#7c52e0"/>',
  '<ellipse cx="60" cy="76" rx="18" ry="20" fill="#cdb6ff"/>',
  # blush
  '<g fill="#ff9ec4" opacity=".3"><ellipse cx="44" cy="66" rx="8" ry="5.5"/><ellipse cx="76" cy="66" rx="8" ry="5.5"/></g>',
  # cute amber proboscis (a friendly snout, not a needle)
  '<path d="M54,76 L66,76 L60,92 Z" fill="#ffc24a"/><path d="M57,80 L63,80 L60,90 Z" fill="#e8920f"/>',
  # eyes
  '<g class="mascot-eyes"><circle cx="50" cy="60" r="7" fill="#1a1030"/><circle cx="70" cy="60" r="7" fill="#1a1030"/>',
  '<circle cx="48" cy="57.5" r="2.6" fill="#ffffff"/><circle cx="68" cy="57.5" r="2.6" fill="#ffffff"/></g>',
  '</svg>'))
