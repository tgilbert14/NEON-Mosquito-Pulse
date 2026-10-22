# ===========================================================================
# NEON Mosquito Pulse: one-page US-letter site report PDF (base graphics).
# grDevices::cairo_pdf + graphics only: no LaTeX, no rmarkdown, no new
# packages. Every section is wrapped so a missing or odd input draws a plain
# "not available" line instead of erroring, so the downloadHandler never fails.
#
# build_mos_report_pdf(file, label, sv, board, peak, meta,
#                      coarse_share = NA_real_, top_note = NULL)
#   sv    list from site_vectors() (n_taxa, index, pct_female, effort_days,
#         n_occ, optional top_share, index_excl_top); every field optional
#   board data.frame from vector_board() (scientificName, genus, index, ...)
#   peak  list(week, n_years, years_total, month_label) from pulse_peak()
#   meta  bundle meta (site, years, release, doi, product, n_occ_attempted,
#         n_zero_catch)
# ===========================================================================

build_mos_report_pdf <- function(file, label, sv, board, peak, meta,
                                 coarse_share = NA_real_, top_note = NULL) {
  # Palette: www/mosquito.css light tokens. Genus colors are the locked data
  # palette from global.R (GENUS_COL), copied so this file stands alone.
  P <- list(navy = "#2a2342", ink = "#221d36", ink2 = "#463d63", muted = "#6f6790",
            terra = "#7c52e0", violet2 = "#5e39c4", pine = "#2a2342", gold = "#e8920f",
            gold_ink = "#9a5f08", paper = "#fbfaff", chip = "#f3f1fa", line = "#ddd6ee",
            band_sub = "#d9d1f3")
  GEN <- c(Culex = "#e8920f", Aedes = "#7c52e0", Anopheles = "#3fb6c9",
           Culiseta = "#5f9e12", Psorophora = "#d94f7a", Coquillettidia = "#8a6fb0",
           other = "#8a8fa3")
  NA_TXT <- "Not available for this site."
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

  ok <- function(expr) tryCatch(expr, error = function(e) NULL)
  fld <- function(x, name) { v <- ok(x[[name]]); if (is.null(v) || !length(v)) NULL else v[[1]] }
  numf <- function(x) { v <- suppressWarnings(as.numeric(x)); if (length(v) && is.finite(v[1])) v[1] else NA_real_ }
  fmt_num <- function(x, digits = 1) {
    v <- numf(x); if (!is.finite(v)) return("n/a")
    if (abs(v) >= 100) return(format(round(v), big.mark = ",", scientific = FALSE))
    if (abs(v) >= 10) digits <- min(digits, 1)
    format(round(v, digits), nsmall = digits, big.mark = ",", scientific = FALSE)
  }
  txt <- function(x, y, s, ...) ok(graphics::text(x, y, s, ...))
  section <- function(expr, x = 3, y = 50) {
    r <- tryCatch({ force(expr); TRUE }, error = function(e) FALSE)
    if (!isTRUE(r)) txt(x, y, NA_TXT, col = P$muted, cex = 0.7, adj = 0)
    invisible(r)
  }
  if (!is.list(sv)) sv <- list()
  if (!is.list(meta)) meta <- list()
  if (!is.list(peak)) peak <- list()

  grDevices::cairo_pdf(file, width = 8.5, height = 11, bg = P$paper)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par(no.readonly = TRUE); on.exit(ok(graphics::par(old)), add = TRUE)
  graphics::par(family = "", mar = c(0, 0, 0, 0), oma = c(0, 0, 0, 0), xpd = NA)
  graphics::plot.new(); graphics::plot.window(xlim = c(0, 100), ylim = c(0, 100), xaxs = "i", yaxs = "i")

  product <- as.character(fld(meta, "product") %||% "DP1.10043.001")
  release <- as.character(fld(meta, "release") %||% "RELEASE-2026")
  doi <- as.character(fld(meta, "doi") %||% "10.48443/rmw1-me46")
  doi_url <- if (grepl("^https?://", doi)) doi else paste0("https://doi.org/", sub("^doi:", "", doi))

  # ---- header band ---------------------------------------------------------
  section({
    graphics::rect(0, 91.5, 100, 100, col = P$navy, border = NA)
    graphics::rect(0, 91.1, 100, 91.5, col = P$gold, border = NA)
    graphics::text(4, 97.2, "NEON Mosquito Pulse · Site report", col = "#ffffff", cex = 1.5, font = 2, adj = 0)
    graphics::text(4, 94.0, as.character(label %||% "Site")[1], col = P$gold, cex = 1.0, font = 2, adj = 0)
    graphics::text(96, 94.0, paste0(format(Sys.Date(), "%Y-%m-%d"), "  ·  ", product),
                   col = P$band_sub, cex = 0.7, adj = 1)
  }, y = 95)

  # ---- stat chips ----------------------------------------------------------
  section({
    yb <- 80.5; w <- 21.5; gap <- 2; x0 <- 4
    chip <- function(i, v, l) {
      x <- x0 + (i - 1) * (w + gap)
      graphics::rect(x, yb, x + w, yb + 7.5, col = P$chip, border = P$line)
      graphics::text(x + w / 2, yb + 4.9, v, col = P$terra, cex = 1.35, font = 2)
      graphics::text(x + w / 2, yb + 1.7, l, col = P$muted, cex = 0.56)
    }
    n_taxa <- numf(fld(sv, "n_taxa"))
    pf <- numf(fld(sv, "pct_female"))
    chip(1, if (is.finite(n_taxa)) format(n_taxa, big.mark = ",") else "n/a", "SPECIES")
    chip(2, fmt_num(fld(sv, "index"), 2), "MOSQUITOES PER 24 TRAP-HOURS")
    chip(3, if (is.finite(pf)) paste0(round(pf), "%") else "n/a", "FEMALE SHARE")
    chip(4, fmt_num(fld(sv, "effort_days"), 1), "24-HOUR EFFORT UNITS")
  }, y = 84)

  # ---- caveat + notes under the index -------------------------------------
  y_note <- 77.6
  section({
    graphics::text(4, y_note, "Mosquitoes per 24 trap-hours is an activity index, not a population, infection or disease-risk measure.",
                   col = P$ink2, cex = 0.68, font = 3, adj = 0)
  }, y = y_note)
  y_note <- y_note - 2.1
  if (!is.null(top_note) && length(top_note) && !is.na(top_note[1]) && nzchar(top_note[1])) {
    section({
      lines <- strwrap(as.character(top_note[1]), width = 120)
      for (ln in lines) { graphics::text(4, y_note, ln, col = P$gold_ink, cex = 0.64, adj = 0); y_note <- y_note - 1.7 }
    }, y = y_note)
  }
  cs <- numf(coarse_share)
  if (is.finite(cs) && cs >= 0.05) {
    section({
      graphics::text(4, y_note, sprintf("%d%% of the catch was identified only to genus or a coarser group, so it counts in the index but not in the species tally.",
                                        round(100 * min(1, cs))), col = P$ink2, cex = 0.64, adj = 0)
      y_note <- y_note - 1.7
    }, y = y_note)
  }

  # ---- top species bars ----------------------------------------------------
  head_y <- 70.5
  txt(4, head_y, "Most active species · mosquitoes per 24 trap-hours", col = P$violet2, cex = 1.0, font = 2, adj = 0)
  graphics::segments(4, head_y - 1.4, 96, head_y - 1.4, col = P$line)
  section({
    b <- if (is.data.frame(board)) board else NULL
    if (is.null(b) || !nrow(b) || !all(c("scientificName", "index") %in% names(b))) {
      graphics::text(4, 62, "No species-level mosquitoes were recorded in this bundle.", col = P$muted, cex = 0.72, adj = 0)
    } else {
      b$index <- suppressWarnings(as.numeric(b$index))
      b <- b[is.finite(b$index), , drop = FALSE]
      b <- utils::head(b[order(-b$index), , drop = FALSE], 8)
      if (!nrow(b)) {
        graphics::text(4, 62, "No species-level mosquitoes were recorded in this bundle.", col = P$muted, cex = 0.72, adj = 0)
      } else {
        b <- b[nrow(b):1, , drop = FALSE]
        n <- nrow(b); xl <- 34; xr <- 86; ytop <- 66.5; ybot <- 48.5
        mx <- max(b$index, na.rm = TRUE)
        step <- (ytop - ybot) / 8
        yc <- ytop - step * (rev(seq_len(n)) - 1) - step / 2   # pack from the top
        bh <- step * 0.62
        gen <- if ("genus" %in% names(b)) as.character(b$genus) else sub(" .*", "", as.character(b$scientificName))
        for (i in seq_len(n)) {
          wv <- if (is.finite(mx) && mx > 0) (xr - xl) * b$index[i] / mx else 0
          col <- GEN[gen[i]]; if (is.na(col)) col <- GEN[["other"]]
          graphics::rect(xl, yc[i] - bh / 2, xl + max(wv, 0.15), yc[i] + bh / 2, col = col, border = NA)
          nm <- as.character(b$scientificName[i]); if (is.na(nm) || !nzchar(nm)) nm <- "unnamed"
          if (nchar(nm) > 40) nm <- paste0(substr(nm, 1, 39), "...")
          graphics::text(xl - 1.5, yc[i], nm, col = P$ink, cex = 0.66, adj = 1, font = 3)
          graphics::text(xl + max(wv, 0.15) + 1, yc[i], fmt_num(b$index[i], 2), col = P$ink2, cex = 0.62, adj = 0)
        }
        shown <- unique(gen[!is.na(gen)])
        shown <- shown[order(match(shown, names(GEN)))]
        if (length(shown)) {
          lx <- 34
          for (g in utils::head(shown, 6)) {
            cg <- GEN[g]; if (is.na(cg)) cg <- GEN[["other"]]
            graphics::rect(lx, 46.4, lx + 1.6, 47.4, col = cg, border = NA)
            graphics::text(lx + 2.2, 46.9, g, col = P$muted, cex = 0.56, adj = 0, font = 3)
            lx <- lx + 3.2 + graphics::strwidth(g, cex = 0.56)
          }
        }
        top_share <- numf(fld(sv, "top_share")); ix_ex <- numf(fld(sv, "index_excl_top"))
        if (is.finite(top_share) || is.finite(ix_ex)) {
          parts <- c(if (is.finite(top_share)) sprintf("The top species makes up %d%% of the catch", round(if (top_share <= 1) 100 * top_share else top_share)),
                     if (is.finite(ix_ex)) sprintf("the site index without it is %s", fmt_num(ix_ex, 2)))
          graphics::text(4, 44.4, paste0(paste(parts, collapse = "; "), "."), col = P$ink2, cex = 0.64, adj = 0)
        }
      }
    }
  }, x = 4, y = 60)

  # ---- seasonal peak -------------------------------------------------------
  txt(4, 40.5, "Seasonal pulse", col = P$violet2, cex = 1.0, font = 2, adj = 0)
  graphics::segments(4, 39.1, 96, 39.1, col = P$line)
  section({
    wk <- numf(fld(peak, "week"))
    ny <- numf(fld(peak, "n_years")); yt <- numf(fld(peak, "years_total"))
    ml <- fld(peak, "month_label")
    s <- if (!is.finite(wk)) {
      "No clear peak in the weekly activity index."
    } else {
      mo <- if (!is.null(ml) && !is.na(ml) && nzchar(ml)) paste0(" (", ml, ")") else ""
      tail_s <- if (is.finite(yt) && yt == 1) ", in the one season trapped here."
        else if (is.finite(ny) && is.finite(yt)) sprintf(", in %d of %d years trapped.", round(ny), round(yt))
        else "."
      paste0("Activity peaked around week ", round(wk), mo, tail_s)
    }
    graphics::text(4, 36.8, s, col = P$ink, cex = 0.8, adj = 0)
    graphics::text(4, 34.6, "The weekly index is a median across years, so one unusual year does not set the peak.",
                   col = P$muted, cex = 0.62, adj = 0)
  }, x = 4, y = 36.8)

  # ---- data coverage -------------------------------------------------------
  txt(4, 30.5, "Data covered", col = P$violet2, cex = 1.0, font = 2, adj = 0)
  graphics::segments(4, 29.1, 96, 29.1, col = P$line)
  section({
    yrs <- suppressWarnings(as.integer(meta$years)); yrs <- yrs[is.finite(yrs)]
    ytxt <- if (length(yrs)) {
      r <- range(yrs)
      if (r[1] == r[2]) sprintf("Data: %d (one season).", r[1])
      else sprintf("Data: %d to %d (%d seasons with trapping).", r[1], r[2], length(unique(yrs)))
    } else "Data: years not available."
    graphics::text(4, 26.8, ytxt, col = P$ink, cex = 0.8, adj = 0)
    na_ <- numf(fld(meta, "n_occ_attempted")); nz <- numf(fld(meta, "n_zero_catch"))
    if (is.finite(na_)) {
      s2 <- sprintf("%s trap collections were attempted", format(round(na_), big.mark = ","))
      if (is.finite(nz)) s2 <- paste0(s2, sprintf(", and %s of them (%d%%) caught no mosquitoes. Those zeros stay in the effort.",
                                                 format(round(nz), big.mark = ","), round(100 * nz / max(1, na_))))
      else s2 <- paste0(s2, ".")
      graphics::text(4, 24.6, s2, col = P$ink2, cex = 0.66, adj = 0)
    }
    graphics::text(4, 22.4, "A CO2 trap draws host-seeking females, so the catch reflects trap pull and weather as well as how many mosquitoes are around.",
                   col = P$muted, cex = 0.62, adj = 0)
  }, x = 4, y = 26.8)

  # ---- footer: citation ----------------------------------------------------
  section({
    graphics::segments(4, 12.5, 96, 12.5, col = P$line)
    cite <- paste0("NEON (National Ecological Observatory Network). Mosquitoes sampled from CO2 traps (", product, "), ",
                   release, ". ", doi_url, ". CC BY 4.0. Not affiliated with NEON, Battelle or the NSF. Built by Desert Data Labs.")
    yy <- 10.6
    for (ln in strwrap(cite, width = 135)) { graphics::text(4, yy, ln, col = P$muted, cex = 0.58, adj = 0); yy <- yy - 1.6 }
    graphics::text(4, 3.2, "desertdatalabs.com", col = P$muted, cex = 0.56, adj = 0)
  }, x = 4, y = 9)

  invisible(TRUE)
}
