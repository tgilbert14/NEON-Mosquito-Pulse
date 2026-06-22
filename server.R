# ===========================================================================
# NEON Mosquito Pulse — server.R
# ===========================================================================
server <- function(input, output, session) {
  is_dark <- function() identical(input$colorMode, "dark")
  plotly_theme <- function(p, legend = TRUE) {
    dark <- is_dark(); ink <- if (dark) "#e9e4fb" else "#221d36"
    grid <- if (dark) "rgba(233,228,251,0.09)" else "rgba(34,29,54,0.07)"; zero <- if (dark) "rgba(233,228,251,0.20)" else "rgba(34,29,54,0.14)"
    lin <- if (dark) "#2f2750" else "#ddd6ee"; legc <- if (dark) "#c3badf" else "#463d63"
    p %>% plotly::layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
      font = list(color = ink, family = "Rubik"),
      xaxis = list(gridcolor = grid, zerolinecolor = zero, linecolor = lin),
      yaxis = list(gridcolor = grid, zerolinecolor = zero, linecolor = lin),
      legend = list(bgcolor = "rgba(0,0,0,0)", orientation = "h", y = -0.2, font = list(color = legc)),
      margin = list(l = 55, r = 30, t = 48, b = 44),
      hoverlabel = list(bgcolor = if (dark) "rgba(27,21,48,0.97)" else "rgba(34,29,54,0.95)", bordercolor = "#b8f24a", font = list(color = "#fff", family = "Rubik", size = 13))) %>%
      plotly::config(displayModeBar = FALSE, responsive = TRUE)
  }
  note_plot <- function(msg, icon = "\U0001F99F") plotly::plot_ly(type="scatter", mode="markers") %>%
    plotly::layout(paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)", xaxis=list(visible=FALSE), yaxis=list(visible=FALSE),
      annotations=list(list(text=paste0(icon,"<br>",msg), showarrow=FALSE, font=list(color=if(is_dark())"#9b91c0" else "#6f6790", size=15), align="center"))) %>%
    plotly::config(displayModeBar = FALSE)

  rv <- reactiveValues(obs=NULL, traps=NULL, board=NULL, tn=0, nocc=0, effw=NULL, label=NULL, site=NULL, sp=NULL, ctx=NULL, is_demo=FALSE, grid=NULL)

  observe({ ch <- mos_state_choices(); updateSelectInput(session, "stateSel", choices = ch, selected = if ("AZ" %in% ch) "AZ" else NULL) })
  observeEvent(input$stateSel, updateSelectInput(session, "site", choices = mos_sites_in_state(input$stateSel)), ignoreInit = FALSE)
  output$siteBio <- renderUI({ req(input$site); b <- site_bio(input$site); if (is.null(b)) return(NULL); div(class="site-bio", bs_icon("info-circle-fill"), span(b)) })
  output$siteCards <- renderUI({
    if (is.null(SITE_INDEX) || !nrow(site_table)) return(NULL)
    div(class="site-cards", lapply(seq_len(nrow(site_table)), function(i){ r <- site_table[i,]
      tags$a(class="site-card", href="#",
        onclick=sprintf("smtLoadStart('%s · loading…');Shiny.setInputValue('pickSite','%s',{priority:'event'});return false;", gsub("'","",r$name), r$site),
        div(class="sc-emoji","\U0001F99F"),
        div(class="sc-body", div(class="sc-name", tags$b(r$site), sprintf(" · %s", r$name)),
          div(class="sc-meta", sprintf("%s · %s species · %s / trap-night", r$state, r$taxa %||% "—", r$mos_per_tn %||% "—")))) }))
  })
  shinyjs::hide("mainTabsWrap")

  ingest <- function(b, label, is_demo = FALSE) {
    if (is.null(b) || is.null(b$obs) || !nrow(b$obs)) {
      session$sendCustomMessage("loadDone", list())   # dismiss the overlay immediately; never wait on the 90s timer
      showNotification(HTML("No mosquito data is bundled yet. Run <code>Rscript scripts/build_synth_bundle.R</code> (or the real fetch) to populate <code>data/</code>."),
                       type = "error", duration = 12)
      return(invisible())
    }
    rv$obs <- b$obs; rv$traps <- b$traps
    rv$tn <- b$meta$trap_nights %||% (if (!is.null(b$traps$trap_nights)) sum(b$traps$trap_nights, na.rm = TRUE) else NA_real_)
    rv$nocc <- b$meta$n_occ_attempted %||% dplyr::n_distinct(b$obs$sampleID)
    rv$effw <- b$effort_week
    rv$board <- vector_board(b$obs, rv$nocc, rv$tn)
    rv$label <- label; rv$site <- b$meta$site; rv$is_demo <- is_demo; rv$sp <- NULL; rv$grid <- NULL
    yrs <- range(b$obs$year, na.rm=TRUE); rv$ctx <- paste0(b$meta$site, " · ", if (yrs[1]==yrs[2]) yrs[1] else paste0(yrs[1],"–",yrs[2]))
    shinyjs::show("mainTabsWrap"); shinyjs::show("spPickerWrap"); shinyjs::hide("splash")
    ch <- setNames(rv$board$scientificName, sprintf("%s · %s", rv$board$vernacular %||% rv$board$scientificName, rv$board$scientificName))
    updateSelectizeInput(session, "spSel", choices = c("Pick a species…"="", ch), selected = "", server = TRUE)
    nav_select("tabs", "overview"); session$sendCustomMessage("countUp", list()); session$sendCustomMessage("loadDone", list())
    invisible(TRUE)
  }
  load_site <- function(site){ if (is.null(site)||site=="") { session$sendCustomMessage("loadDone", list()); return() }
    b <- load_site_bundle(site); if (is.null(b)) { session$sendCustomMessage("loadDone", list()); showNotification("That site isn't bundled.", type="error"); return() }
    row <- site_table[site_table$site==site,]; ingest(b, sprintf("%s · %s", site, if (nrow(row)) row$name else site)) }
  observeEvent(input$loadBtn, load_site(input$site)); observeEvent(input$pickSite, load_site(input$pickSite))
  observeEvent(input$demoBtn, ingest(load_demo(), DEMO_META$label, is_demo=TRUE)); observeEvent(input$demoBtn2, ingest(load_demo(), DEMO_META$label, is_demo=TRUE))

  pick_species <- function(sci, navigate=FALSE){ if (is.null(sci)||is.na(sci)||sci=="") return()
    if (is.null(rv$board) || !(sci %in% rv$board$scientificName)) return()
    rv$sp <- sci; if (!identical(input$spSel, sci)) updateSelectizeInput(session, "spSel", selected=sci); if (navigate) nav_select("tabs","species") }
  observeEvent(input$spSel, if (nzchar(input$spSel %||% "")) pick_species(input$spSel, navigate=TRUE), ignoreInit=TRUE)
  observeEvent(input$qcCardRequest, if (nzchar(input$qcCardRequest %||% "")) pick_species(input$qcCardRequest, navigate=TRUE), ignoreInit=TRUE)
  observeEvent(input$surpriseBtn, { req(rv$board); pick_species(sample(rv$board$scientificName, 1), navigate=TRUE) })
  observeEvent(input$goPulse, nav_select("tabs","pulse")); observeEvent(input$goBoard, nav_select("tabs","board"))
  observeEvent(input$goSpecies, { if (is.null(rv$sp) && !is.null(rv$board)) rv$sp <- rv$board$scientificName[1]; nav_select("tabs","species") })
  observeEvent(input$goMap, nav_select("tabs","map"))
  observeEvent(input$goClimate, nav_select("tabs","climate"))

  # ---- hero ----
  output$heroStats <- renderUI({
    sv <- site_vectors(rv$obs, rv$nocc, rv$tn, rv$effw, if (!is.null(rv$traps)) nrow(rv$traps) else NA); if (is.null(sv)) return(NULL)
    hero <- function(v,l,suf="",icon,tone,info=NULL) div(class=paste0("hero-stat hero-",tone),
      div(class="hs-icon", bs_icon(icon)),
      div(div(class="hs-v count-up", `data-target`=v, `data-suffix`=suf, "0"),
          div(class="hs-l", l, if (!is.null(info)) info)))
    div(class="hero-band", div(class="hero-title", bs_icon("broadcast"), tags$b(rv$label)),
      div(class="hero-grid",
        hero(sv$n_taxa, "species", icon="bug-fill", tone="navy",
          info=info_pop("Species", p("The number of different mosquito species ", tags$b("caught"), " here across all years. CO2 traps miss day-active and rare species, so the true total is higher (see the Chao2 estimate)."))),
        hero(sv$index, "per trap-night", icon="activity", tone="terra",
          info=info_pop("Activity index", p("Average mosquitoes caught per ", tags$b("trap-night"), ", a within-site ", tags$b("activity index, not a population"), ". CO2 traps lure host-seeking females, so a hot, humid night inflates it independent of true numbers."))),
        hero(sv$pct_female, "% female", suf="%", icon="gender-female", tone="pine",
          info=info_pop("Female share", p("Share of sexed mosquitoes that were female. CO2 traps ", tags$b("select for host-seeking females"), " by design, so a near-all-female catch is the trap working, not a real sex ratio. Males show up mostly as bycatch."))),
        hero(sv$trap_nights, "trap-nights", icon="moon-stars", tone="gold",
          info=info_pop("Trap-nights", p("The total ", tags$b("trap-nights"), " of effort here (sum of trapHours ÷ 24). This is the denominator behind the per-trap-night activity index.")))))
  })

  # ---- Overview ----
  output$topBar <- renderPlotly({
    brd <- rv$board; req(brd); brd <- head(brd[order(-brd$index),], 16)
    brd$lab <- factor(brd$vernacular %||% brd$scientificName, levels = rev(brd$vernacular %||% brd$scientificName))
    plot_ly(brd, x=~index, y=~lab, type="bar", orientation="h", marker=list(color=genus_col(brd$genus)),
      text=~paste0(genus), customdata=~ubiquity,
      hovertemplate="%{y}<br>%{x:.2f} per trap-night · on %{customdata}% of nights · %{text}<extra></extra>") %>%
      plotly_theme(legend=FALSE) %>% plotly::layout(showlegend=FALSE, xaxis=list(title="Activity index (mosquitoes / trap-night)"), yaxis=list(title=""), margin=list(l=180, t=34),
        annotations=list(list(text=sprintf("at <b>%s</b> · this site only · colour = genus", rv$site %||% "this site"), x=0, y=1.07, xref="paper", yref="paper", showarrow=FALSE, xanchor="left", font=list(color=if(is_dark())"#9b91c0" else "#6f6790", size=11))))
  })
  output$overviewInsight <- renderUI({
    brd <- rv$board; req(brd); top <- brd[which.max(brd$index),]; ubi <- brd[which.max(brd$ubiquity),]
    insight_banner("activity", tone="navy", HTML(sprintf("<b>%s</b> is the most-active mosquito here (%.2f per trap-night); <b>%s</b> is the most widespread (on %.0f%% of trap-nights). The site holds <span class='ci-hero'>%d</span> species.",
      top$vernacular %||% top$scientificName, top$index, ubi$vernacular %||% ubi$scientificName, ubi$ubiquity, nrow(brd))))
  })
  output$siteInsights <- renderUI({
    brd <- rv$board; req(brd); ch <- chao2_collections(rv$obs, rv$nocc)
    yrs <- range(rv$obs$year, na.rm=TRUE); yr_lab <- if (yrs[1]==yrs[2]) as.character(yrs[1]) else sprintf("%d–%d", yrs[1], yrs[2])
    top <- brd[which.max(brd$index),]; ubi <- brd[which.max(brd$ubiquity),]
    nm <- function(r) r$vernacular %||% r$scientificName
    gs <- genus_share(rv$obs); culex <- if (!is.null(gs)) gs$share[gs$genus=="Culex"] else NA
    pts <- c(
      sprintf("Over <b>%s</b>, NEON ran about <b>%s</b> trap-nights here and caught an estimated <b>%s</b> mosquitoes of <b>%d</b> species.",
        yr_lab, fmt_int(rv$tn), fmt_int(sum(brd$total)), nrow(brd)),
      sprintf("The most-active mosquito is the <b>%s</b> (<i>%s</i>), about <b>%.2f</b> per trap-night; the most <i>widespread</i> is the <b>%s</b>, on <b>%.0f%%</b> of trap-nights.",
        nm(top), top$scientificName, top$index, nm(ubi), ubi$ubiquity))
    if (length(culex) && !is.na(culex) && culex > 0)
      pts <- c(pts, sprintf("<b>Culex</b>, the West Nile vector group, makes up about <b>%.0f%%</b> of the catch here. This shows where they are active, not whether any carry a virus.", culex))
    if (!is.null(ch)) {
      cov <- site_coverage(rv$obs, rv$nocc)
      if (ch$unstable && is.finite(cov))
        pts <- c(pts, sprintf("Traps caught <b>%d</b> species, and sample <b>coverage is %.0f%%</b>, so most species present were caught. (A Chao2 extrapolation is unstable here; read the completeness, not a single projected number.)", ch$S_obs, round(100 * cov)))
      else
        pts <- c(pts, sprintf("Traps caught <b>%d</b> species; <b>Chao2</b> (across %s trap-nights) estimates at least <b>%.0f</b> really use the site. CO2 traps miss day-active and rare mosquitoes.", ch$S_obs, fmt_int(ch$m), ch$chao2))
    }
    pts <- c(pts, "Remember: these are a <b>within-site activity index</b>, not a census, and the catch is mostly host-seeking females. Open any species' profile for its sex split and data-quality flags.")
    tags$ul(class="insight-list", lapply(pts, function(t) tags$li(HTML(t))))
  })

  # ---- genus + sex composition strip ----
  output$compStrip <- renderPlotly({
    req(rv$obs); gs <- genus_share(rv$obs); sx <- sex_split(rv$obs)
    if (is.null(gs) || is.null(sx)) return(note_plot("No composition data"))
    sx$share <- round(100 * sx$count / max(1, sum(sx$count)), 1)
    p <- plot_ly()
    for (i in seq_len(nrow(gs))) p <- p %>% add_trace(x = gs$share[i], y = "By genus", type="bar", orientation="h",
      name = gs$genus[i], legendgroup="g", marker=list(color=genus_col(gs$genus[i])),
      hovertemplate=sprintf("%s · %.1f%% of catch<extra></extra>", gs$genus[i], gs$share[i]))
    for (i in seq_len(nrow(sx))) { lab <- unname(sex_lab[sx$sex[i]])
      p <- p %>% add_trace(x = sx$share[i], y = "By sex", type="bar", orientation="h",
        name = lab, legendgroup="s", marker=list(color=sex_col(sx$sex[i])),
        hovertemplate=sprintf("%s · %.1f%% of sexed<extra></extra>", lab, sx$share[i])) }
    p %>% plotly_theme() %>% plotly::layout(barmode="stack", showlegend=TRUE,
      xaxis=list(title="% of catch", ticksuffix="%", range=c(0,100)), yaxis=list(title=""), margin=list(l=70, t=20, b=40))
  })
  output$compInsight <- renderUI({
    req(rv$obs); gs <- genus_share(rv$obs); sx <- sex_split(rv$obs); req(!is.null(gs), !is.null(sx))
    femp <- round(100 * sx$count[sx$sex=="F"] / max(1, sum(sx$count)))
    insight_banner("pie-chart", tone="terra", HTML(sprintf("The catch is <b>%.0f%%</b> %s and <span class='ci-hero'>%.0f%% female</span>. Female-heavy is the CO2 trap doing its job, not a population sex ratio.",
      gs$share[1], gs$genus[1], femp)))
  })

  # ---- The Pulse (signature) ----
  output$pulsePlot <- renderPlotly({
    req(rv$obs); pk <- pulse_phenology(rv$obs, rv$effw); if (is.null(pk) || nrow(pk) < 2) return(note_plot("Not enough weekly trapping to draw a pulse"))
    cl <- if (!is.null(SITE_CLIMATE)) SITE_CLIMATE[SITE_CLIMATE$site == rv$site, , drop = FALSE] else NULL
    muted <- if (is_dark()) "#9b91c0" else "#6f6790"
    p <- plot_ly()
    # ±1 SE ribbon between years
    if (any(pk$se > 0)) p <- p %>%
      add_trace(x=c(pk$week, rev(pk$week)), y=c(pk$index+pk$se, rev(pk$index-pk$se)), type="scatter", mode="lines",
        fill="toself", fillcolor="rgba(124,82,224,0.14)", line=list(width=0), name="±1 SE", hoverinfo="skip", showlegend=FALSE)
    p <- p %>% add_trace(x=~pk$week, y=~pk$index, type="scatter", mode="lines+markers", name="Activity",
      line=list(color=DDL$violet, width=3), marker=list(color=DDL$violet, size=6),
      customdata=~pk$n_years, hovertemplate="week %{x}<br>%{y:.1f} / trap-night<br>%{customdata} years<extra></extra>")
    shp <- list()
    if (!is.null(cl) && nrow(cl) && !is.null(cl$monsoon_month_min) && !is.na(cl$monsoon_month_min) && isTRUE(cl$has_gauge)) {
      wlo <- (cl$monsoon_month_min - 1) * 4.345; whi <- cl$monsoon_month_max * 4.345
      shp <- list(list(type="rect", xref="x", yref="paper", x0=wlo, x1=whi, y0=0, y1=1,
        fillcolor="rgba(95,158,18,0.14)", line=list(width=0), layer="below"))
    }
    band_note <- if (length(shp)) " · shaded band = the monsoon window" else " · no rain gauge here, so no monsoon band"
    p %>% plotly_theme() %>% plotly::layout(shapes=shp,
      xaxis=list(title="Week of the year", range=c(0,53)), yaxis=list(title="Mosquitoes / trap-night", rangemode="tozero"),
      margin=list(l=56, r=20, t=44, b=44),
      annotations=list(list(text=sprintf("at <b>%s</b>%s", rv$site %||% "this site", band_note), x=0, y=1.1, xref="paper", yref="paper", showarrow=FALSE, xanchor="left", font=list(color=muted, size=11))))
  })
  output$pulseInsight <- renderUI({
    req(rv$obs); pk <- pulse_phenology(rv$obs, rv$effw); req(!is.null(pk), nrow(pk) >= 2)
    pw <- pk$week[which.max(pk$index)]; pm <- format(as.Date("2021-01-01") + (pw*7 - 7), "%B")
    cl <- if (!is.null(SITE_CLIMATE)) SITE_CLIMATE[SITE_CLIMATE$site == rv$site, , drop = FALSE] else NULL
    desert <- identical(biome_of(rv$site), "desert")
    msg <- if (desert)
      sprintf("Activity peaks around <b>week %d (%s)</b>. In this water-limited desert the pulse rides the <b>summer monsoon</b>: rain fills ephemeral water, and adults emerge a couple of weeks later.", pw, pm)
    else
      sprintf("Activity peaks around <b>week %d (%s)</b>. In this cooler, wetter system the pulse is paced by <b>warmth and degree-days</b> rather than the monsoon.", pw, pm)
    insight_banner("activity", tone="navy", HTML(msg))
  })

  # ---- Community (on the Pulse tab) ----
  output$accumPlot <- renderPlotly({
    ac <- mos_accum(rv$obs, rv$traps); if (is.null(ac)) return(note_plot("Not enough collection occasions for an accumulation curve"))
    plot_ly(ac, x=~occasions, y=~richness, type="scatter", mode="lines", line=list(color=DDL$violet, width=3),
      fill="tozeroy", fillcolor="rgba(124,82,224,0.08)",
      hovertemplate="%{x} trap-nights<br>%{y:.0f} species<extra></extra>") %>%
      plotly_theme(legend=FALSE) %>% plotly::layout(xaxis=list(title="Collection occasions (trap-nights)"), yaxis=list(title="Species found"))
  })
  output$accumInsight <- renderUI({
    ac <- mos_accum(rv$obs, rv$traps); req(!is.null(ac))
    slope <- ac$richness[nrow(ac)] - ac$richness[max(1,nrow(ac)-5)]
    insight_banner("graph-up", tone="pine", HTML(sprintf("By <b>%d</b> trap-nights, <span class='ci-hero'>%.0f</span> species had turned up.%s",
      ac$occasions[nrow(ac)], ac$richness[nrow(ac)], if (slope > 1) " The curve is still rising; more trapping would find more species." else " The curve is flattening; most catchable species have been found.")))
  })
  output$chaoBanner <- renderUI({
    ch <- chao2_collections(rv$obs, rv$nocc); req(!is.null(ch)); cov <- site_coverage(rv$obs, rv$nocc)
    ci_txt <- if (is.finite(ch$ci_lo) && is.finite(ch$ci_hi)) sprintf("%.0f–%.0f species", ch$ci_lo, ch$ci_hi) else "wide"
    chao_pop <- info_pop("Chao2 estimate",
      p(tags$b("Chao2"), " estimates ", tags$b(sprintf("%.0f", ch$chao2)), " species use the site (95% CI ", tags$b(ci_txt), "; Chao 1987), so roughly ", tags$b(sprintf("%.0f", max(0, round(ch$chao2 - ch$S_obs)))), " remain uncaught."),
      if (ch$unstable) p(class="pop-caveat", bsicons::bs_icon("exclamation-triangle"),
        sprintf(" Only %d species were caught at exactly two occasions (Q2=%d), so this point estimate is volatile. Read the CI and the coverage, not the single number.", ch$Q2, ch$Q2)))
    if (ch$unstable && is.finite(cov))
      insight_banner("calculator", tone="gold", HTML(sprintf("Caught <b>%d</b> species across %d trap-nights. Sample <b>coverage is %.0f%%</b>, so most species present were caught. A Chao2 extrapolation is unstable here (only %d caught twice). ", ch$S_obs, ch$m, round(100 * cov), ch$Q2)), chao_pop)
    else
      insight_banner("calculator", tone="gold", HTML(sprintf("Caught <b>%d</b> species across %d trap-nights. <b>Chao2</b> estimates <span class='ci-hero'>%.0f</span> use the site (95%% CI %s). Roughly <b>%.0f</b> remain uncaught.",
        ch$S_obs, ch$m, ch$chao2, ci_txt, max(0, round(ch$chao2 - ch$S_obs)))), chao_pop)
  })

  # ---- Swarm Board (flagship) ----
  output$swarmBoard <- renderPlotly({
    brd <- rv$board; req(brd)
    brd$reliable <- brd$n_occ_present >= 3
    brd$col <- genus_col(brd$genus); brd$col[!brd$reliable] <- "rgba(138,135,160,0.35)"
    brd$tip <- paste0("<span class='smt-pin-emoji'>\U0001F99F</span> <b>", brd$vernacular %||% brd$scientificName, "</b><br/>",
      "<em>", brd$scientificName, " · ", brd$genus, "</em><br/>",
      "<span class='smt-pin-stats'>", brd$index, " / trap-night · on ", brd$ubiquity, "% of nights<br/>",
      ifelse(is.na(brd$female_share), "sex not recorded", paste0(brd$female_share, "% female")), " · ", round(brd$total), " caught</span>",
      ifelse(brd$reliable, "", "<br/><span class='smt-pin-rar' style='color:#ffd9a7'>⚠ few nights</span>"),
      "<br/><span class='smt-open' role='button' tabindex='0' data-tag='", brd$scientificName, "'>\U0001F9EC Open species profile &rarr;</span>",
      "<br/><em class='smt-pin-hint'>Tap the dot to pin this card</em>")
    qcol <- if (is_dark()) "#9b91c0" else "#a99fce"; muted <- if (is_dark()) "#9b91c0" else "#6f6790"
    p <- plot_ly()
    for (g in unique(brd$genus)) { sub <- brd[brd$genus %in% g, ]
      p <- p %>% add_trace(data=sub, x=~ubiquity, y=~index, type="scatter", mode="markers", name=g %||% "—",
        customdata=~tip, marker=list(color=sub$col, size=12, opacity=0.82, line=list(color="#fff", width=0.5)),
        text=~paste0(vernacular %||% scientificName), hovertemplate="%{text}<br>%{x}% of nights · %{y:.2f}/trap-night<extra></extra>") }
    mx <- stats::median(brd$ubiquity); my <- stats::median(brd$index[brd$reliable])
    xr <- range(brd$ubiquity); yr <- range(brd$index); px <- diff(xr)*0.02; py <- diff(yr)*0.02
    qlab <- function(x,y,t,xa,ya) list(text=t, x=x, y=y, xref="x", yref="y", showarrow=FALSE, xanchor=xa, yanchor=ya, font=list(color=qcol, size=10.5))
    ann <- list(list(text=sprintf("at <b>%s</b> (this site) · each dot is a species · ubiquity × activity (not a population) · colour = genus", rv$site %||% "this site"), x=0, y=1.07, xref="paper", yref="paper", showarrow=FALSE, xanchor="left", font=list(color=muted, size=11)),
      qlab(xr[2]-px, yr[2]-py, "EVERYWHERE & BUSY \U0001F525", "right", "top"),
      qlab(xr[1]+px, yr[2]-py, "LOCALLY BUSY", "left", "top"),
      qlab(xr[2]-px, yr[1]+py, "THINLY EVERYWHERE", "right", "bottom"),
      qlab(xr[1]+px, yr[1]+py, "SELDOM CAUGHT", "left", "bottom"))
    if (!is.null(rv$sp)) { ir <- brd[brd$scientificName == rv$sp, ]
      if (nrow(ir)==1) p <- p %>% add_trace(x=ir$ubiquity, y=ir$index, type="scatter", mode="markers", name="★ viewing", customdata=ir$tip, showlegend=TRUE,
        marker=list(symbol="diamond", size=18, color="#e8920f", line=list(color="#fff", width=1.6)), hovertemplate=paste0("viewing ", ir$vernacular %||% ir$scientificName, "<extra></extra>")) }
    p %>% plotly_theme() %>% plotly::layout(xaxis=list(title="Ubiquity (% of trap-nights present)"), yaxis=list(title="Activity index (mosquitoes / trap-night)", rangemode="tozero"),
      shapes=list(list(type="line", xref="x", yref="paper", x0=mx, x1=mx, y0=0, y1=1, line=list(color=qcol, dash="dot", width=1)),
                  list(type="line", xref="paper", yref="y", x0=0, x1=1, y0=my, y1=my, line=list(color=qcol, dash="dot", width=1))),
      annotations=ann, hovermode="closest")
  })
  output$spCardSlot <- renderUI({
    if (is.null(rv$sp)) return(div(class="qc-empty", div(class="qc-empty-icon","\U0001F99F"), h4("Tap a species to see its card"),
      p("Tap a dot above and choose “Open species profile”, or pick a species in the sidebar.")))
    r <- rv$board[rv$board$scientificName == rv$sp,]; if (!nrow(r)) return(NULL)
    div(class="lab-sel", span(class="ls-emoji","\U0001F9EC"),
      div(class="ls-body", div(class="ls-id", tags$b(r$vernacular %||% r$scientificName), sprintf(" · %.2f / trap-night · %.0f%% of nights", r$index, r$ubiquity)),
        div(class="ls-dom", em(r$scientificName), sprintf(" · %s", r$genus))),
      actionButton("goSpFromCard", tagList(bs_icon("arrows-fullscreen"), " Open full profile"), class="btn-outline-dark btn-sm"))
  })
  observeEvent(input$goSpFromCard, nav_select("tabs","species"))

  # ---- Taxon Profile (downloadable card + QC flags) ----
  output$yearPlot <- renderPlotly({
    sci <- rv$sp; req(sci); my <- catch_by_year(rv$obs, sci); if (is.null(my) || !nrow(my)) return(note_plot("No yearly data"))
    bar_col <- genus_col((rv$board$genus[rv$board$scientificName == sci])[1] %||% "other")
    plot_ly(my, x=~year, y=~mosquitoes, type="bar", marker=list(color=bar_col),
            hovertemplate="%{x}<br>%{y} caught (est.)<extra></extra>") %>%
      plotly_theme(legend=FALSE) %>% plotly::layout(xaxis=list(title="Year"), yaxis=list(title="Mosquitoes (est.)"), margin=list(l=46,r=10,t=10,b=40))
  })
  output$sexPlot <- renderPlotly({
    sci <- rv$sp; req(sci); sx <- sex_split(rv$obs, sci); if (is.null(sx) || !sum(sx$count)) return(note_plot("No sex data"))
    sx$lab <- unname(sex_lab[sx$sex]); sx <- sx[sx$count > 0, ]
    plot_ly(sx, labels=~lab, values=~count, type="pie", hole=0.55, sort=FALSE,
      marker=list(colors=sex_col(sx$sex)), textinfo="label+percent",
      hovertemplate="%{label}<br>%{value} (%{percent})<extra></extra>") %>%
      plotly_theme(legend=FALSE) %>% plotly::layout(showlegend=FALSE, margin=list(l=10,r=10,t=10,b=10))
  })
  qc <- reactive({ req(rv$sp); mos_qc(rv$obs, rv$sp, rv$traps) })
  qc_icon <- function(level) switch(level, high = "exclamation-octagon-fill", warn = "exclamation-triangle-fill", info = "info-circle-fill", "check-circle-fill")

  output$speciesProfile <- renderUI({
    if (is.null(rv$sp)) return(div(class="qc-empty", div(class="qc-empty-icon","\U0001F99F"), h4("Pick a species to open its profile"),
      p("Use the Swarm Board (tap a dot → “Open species profile”) or the sidebar picker.")))
    r <- rv$board[rv$board$scientificName == rv$sp,]; req(nrow(r)==1)
    tile <- function(v,l) div(class="qc-tile", div(class="qc-tile-v", v), div(class="qc-tile-l", l))
    qf <- qc()$flags
    qc_block <- tagList(
      div(class="qc-section-h", bs_icon("clipboard-check"), " Data-quality review flags ",
        tags$span(class="qcf-sub","· verify, not errors")),
      if (length(qf)) tagList(
        div(class="qc-flags", lapply(qf, function(f) div(
          class = paste0("qc-flag qc-flag-", f$level, " qc-flag-click"), role = "button", tabindex = "0",
          onclick = sprintf("Shiny.setInputValue('mosQcInspect','%s',{priority:'event'})", f$key),
          bs_icon(qc_icon(f$level)),
          div(class="qcf-body",
            div(class="qcf-title", f$title, tags$span(class="qcf-n", f$n)),
            div(class="qcf-detail", f$detail)),
          tags$span(class="qcf-go", bs_icon("chevron-right"))))),
        div(class="qcf-hint", bs_icon("hand-index-thumb"), " tap a flag to list the exact records behind it"))
      else div(class="qc-flag qc-flag-ok", bs_icon("check-circle-fill"),
        div(class="qcf-body", div(class="qcf-title","No data-quality flags for this species"),
          div(class="qcf-detail","Trap effort, subsample weights, sex, and identification all look consistent, nothing to verify."))))
    body <- div(id="qcCardNode", class="qc-card", `data-short`=gsub("[^A-Za-z]","",substr(r$vernacular %||% r$scientificName,1,20)),
      div(class="qc-head", span(class="qc-emoji","\U0001F9EC"),
        div(div(class="qc-id", r$vernacular %||% r$scientificName), div(class="qc-sci", em(r$scientificName), sprintf(" · %s", r$genus))),
        div(class="qc-head-badges", glow_badge(paste0(round(r$total), " caught"), DDL$sky))),
      div(class="qc-tiles",
        tile(r$index, "per trap-night"), tile(paste0(r$ubiquity,"%"), "of nights"),
        tile(ifelse(is.na(r$female_share), "—", paste0(r$female_share,"%")), "female"),
        tile(r$n_traps, "traps"), tile(r$detections, "records"), tile(r$genus, "genus")),
      div(class="qc-section-h", bs_icon("gender-female"), " Sex split (CO2 traps select females)"),
      plotlyOutput("sexPlot", height="150px"),
      div(class="qc-section-h", bs_icon("calendar3"), " Mosquitoes caught, by year"),
      plotlyOutput("yearPlot", height="150px"),
      qc_block,
      p(class="qc-cap-note", style="margin-top:8px", bs_icon("info-circle"),
        " Counts are an activity index (per trap-night), not a population, and large catches are weight-scaled estimates. The catch is mostly host-seeking females by trap design."))
    div(div(class="plot-profile-wrap", body), div(class="qc-toolbar",
      tags$button(class="smt-snap-btn", type="button", onclick="smtSaveQcCard()", bsicons::bs_icon("download"), " Save species card (PNG)"),
      downloadButton("spCsv", "Download records (CSV)", class="smt-clear-btn"),
      if (length(qf)) downloadButton("qcReportCsv", "Download QC report (CSV)", class="smt-clear-btn"),
      downloadButton("codebookCsv", "Download column codebook (CSV)", class="smt-clear-btn")),
      uiOutput("mosQcInspector"))
  })

  output$mosQcInspector <- renderUI({
    key <- input$mosQcInspect; q <- qc(); req(!is.null(key), key %in% names(q$sets))
    st <- q$sets[[key]]; req(!is.null(st), nrow(st))
    f <- Filter(function(x) x$key == key, q$flags)[[1]]
    show <- intersect(c("scientificName","sampleID","plotID","trapID","year","collectDate","sex","count","trapHours","targetTaxaPresent","sampleCondition","nightOrDay","expansionFactor","identificationQualifier"), names(st))
    head_n <- min(nrow(st), 200L); sv <- st[seq_len(head_n), show, drop=FALSE]
    div(class="qc-inspector",
      div(class="qci-head", bs_icon(qc_icon(f$level)), tags$b(sprintf(" %s · %d record%s", f$title, f$n, if (f$n==1) "" else "s")),
        downloadButton("qcSubsetCsv", "Download these", class="btn-outline-dark btn-sm qci-dl")),
      div(class="qc-cap-scroll", tags$table(class="inspect-tbl",
        tags$thead(tags$tr(lapply(show, tags$th))),
        tags$tbody(lapply(seq_len(nrow(sv)), function(i)
          tags$tr(lapply(show, function(cc) tags$td(format(sv[[cc]][i]))))) ))),
      if (nrow(st) > head_n) p(class="qc-cap-note", sprintf("Showing first %d of %d. Download for the full list.", head_n, nrow(st))))
  })
  output$qcSubsetCsv <- downloadHandler(
    filename = function() sprintf("NEON-Mosquito_QC-%s_%s_%s.csv", input$mosQcInspect %||% "flag",
      gsub("[^A-Za-z]","",substr(rv$sp %||% "species",1,20)), format(Sys.Date(),"%Y%m%d")),
    content = function(file){ q <- qc(); st <- q$sets[[input$mosQcInspect]]; req(!is.null(st))
      utils::write.csv(st, file, row.names=FALSE, na="") }, contentType="text/csv")
  output$qcReportCsv <- downloadHandler(
    filename = function() sprintf("NEON-Mosquito_QC-report_%s_%s.csv", gsub("[^A-Za-z]","",substr(rv$sp %||% "species",1,20)), format(Sys.Date(),"%Y%m%d")),
    content = function(file){ rep <- mos_qc_report(rv$obs, rv$sp, rv$traps)
      if (is.null(rep)) rep <- data.frame(note="No data-quality flags for this species.")
      utils::write.csv(rep, file, row.names=FALSE, na="") }, contentType="text/csv")
  output$spCsv <- downloadHandler(
    filename = function() sprintf("NEON-Mosquito_%s_%s.csv", gsub("[^A-Za-z]","",substr(rv$sp %||% "species",1,24)), format(Sys.Date(),"%Y%m%d")),
    content = function(file){ sci <- rv$sp; req(sci); d <- species_detail(rv$obs, sci); req(!is.null(d))
      # include the provenance columns an analyst needs to RE-DERIVE count (the whole-
      # trap expansion) and replicate the QC filtering — the export must reproduce itself.
      keep <- intersect(c("scientificName","vernacularName","genus","taxonRank","sampleID","plotID","trapID","year","collectDate","week","sex","count","is_target","nightOrDay","trapHours","subsampleWeight","totalWeight","expansionFactor","targetTaxaPresent","sampleCondition","identificationQualifier","nativeStatusCode"), names(d))
      utils::write.csv(d[, keep], file, row.names=FALSE, na="") },
    contentType="text/csv")
  output$codebookCsv <- downloadHandler(
    filename = function() sprintf("NEON-Mosquito_codebook_%s.csv", format(Sys.Date(),"%Y%m%d")),
    content = function(file) utils::write.csv(mos_codebook(), file, row.names=FALSE, na=""),
    contentType="text/csv")

  # ---- Map (trap grids) ----
  output$map <- leaflet::renderLeaflet({
    obs <- rv$obs; traps <- rv$traps; req(obs, traps)
    g <- point_summary(obs, traps); g <- g[is.finite(g$lat) & is.finite(g$lng), ]
    metric <- input$mapMetric %||% "richness"; val <- g[[metric]]; val[is.na(val)] <- 0
    dom <- if (diff(range(val,na.rm=TRUE))>0) range(val,na.rm=TRUE) else c(val[1]-1,val[1]+1)
    pal <- leaflet::colorNumeric(c("#efe7ff","#b8f24a","#7c52e0","#3a1f7a"), domain=dom)
    rr <- range(g$richness, na.rm=TRUE); g$radius <- if (diff(rr)>0) 7 + 13*(g$richness-rr[1])/diff(rr) else 11
    leaflet::leaflet(g) %>% leaflet::addProviderTiles(input$view %||% "Esri.WorldTopoMap") %>%
      leaflet::addCircleMarkers(lng=~lng, lat=~lat, radius=~radius, fillColor=pal(val), color="#fff", weight=1, fillOpacity=0.85,
        layerId=~plotID,
        label=~lapply(sprintf("<b>%s</b><br>%d species · %s / trap-night<br><span style='color:#7c52e0'>\U0001F446 click for the species list</span>", short_point(plotID), richness, ifelse(is.na(per_tn),"—",per_tn)), htmltools::HTML)) %>%
      leaflet::addLegend("bottomright", pal=pal, values=val, title=if (metric=="richness") "species" else "/ trap-night")
  })
  observeEvent(input$map_marker_click, { id <- input$map_marker_click$id; if (!is.null(id)) rv$grid <- id })
  output$gridPanel <- renderUI({
    if (is.null(rv$obs)) return(NULL)
    if (is.null(rv$grid)) return(div(class="grid-empty", bs_icon("hand-index-thumb"),
      span(" Tap a grid marker above to list every mosquito species caught there, then download it.")))
    gs <- grid_species(rv$obs, rv$grid)
    if (is.null(gs) || !nrow(gs)) return(div(class="grid-empty", bs_icon("info-circle"), span(sprintf(" No mosquito records at grid %s.", short_point(rv$grid)))))
    rows <- lapply(seq_len(nrow(gs)), function(i) {
      lbl <- gs$vernacular[i]; if (is.na(lbl)) lbl <- gs$scientificName[i]
      tags$tr(
        tags$td(tags$b(lbl), tags$br(), tags$em(class="grid-sci", gs$scientificName[i])),
        tags$td(class="grid-num", gs$mosquitoes[i]), tags$td(class="grid-num", gs$detections[i]),
        tags$td(span(class="grid-method", style=sprintf("color:%s", genus_col(gs$genus[i])), gs$genus[i])))
    })
    div(class="grid-card",
      div(class="grid-head",
        div(tags$b(sprintf("Grid %s", short_point(rv$grid))), span(class="grid-sub", sprintf(" · %d species caught here", nrow(gs)))),
        downloadButton("gridSpeciesCsv", "Download species list (CSV)", class="smt-clear-btn")),
      div(class="grid-scroll", tags$table(class="inspect-tbl grid-tbl",
        tags$thead(tags$tr(tags$th("Species"), tags$th(class="grid-num","Caught"), tags$th(class="grid-num","Records"), tags$th("Genus"))),
        tags$tbody(rows))))
  })
  output$gridSpeciesCsv <- downloadHandler(
    filename = function() sprintf("NEON-Mosquito_%s_grid-%s_%s.csv", rv$site %||% "site", gsub("[^A-Za-z0-9]","",short_point(rv$grid %||% "grid")), format(Sys.Date(),"%Y%m%d")),
    content = function(file){ req(rv$grid); gs <- grid_species(rv$obs, rv$grid); req(!is.null(gs))
      utils::write.csv(gs, file, row.names=FALSE, na="") },
    contentType="text/csv")

  # ---- Splash: national site picker -----------------------------------------
  output$nationalPicker <- leaflet::renderLeaflet({
    d <- site_table
    if (is.null(d) || !nrow(d)) {
      # no bundles yet: show the network as muted dots (not a blank map) so it's
      # clear data hasn't been built; the no-data banner above explains how.
      nd <- neon_sites; nd$biome <- biome_of(nd$site); nd$bcol <- biome_col(nd$biome)
      return(leaflet::leaflet(nd) %>% leaflet::addProviderTiles("CartoDB.Positron") %>% leaflet::setView(-96, 41, 3) %>%
        leaflet::addCircleMarkers(lng = ~lng, lat = ~lat, radius = 6, fillColor = ~bcol, color = "#fff", weight = 1, fillOpacity = 0.35,
          label = ~lapply(sprintf("<b>%s</b> · %s<br><span style='color:#9a5f08'>data not built yet</span>", site, name), htmltools::HTML),
          popup = "<div style='font-family:Rubik,sans-serif'>No data is bundled yet.<br>Run <code>scripts/build_synth_bundle.R</code> or the real fetch.</div>"))
    }
    d$biome <- biome_of(d$site); d$bcol <- biome_col(d$biome); d$blab <- unname(BIOME_LAB[d$biome])
    d$taxa <- suppressWarnings(as.numeric(d$taxa)); d$taxa[is.na(d$taxa)] <- 0
    rr <- range(d$taxa, na.rm = TRUE); d$rad <- 6 + 11 * (d$taxa - rr[1]) / max(1, diff(rr))
    pop <- sprintf("<div style='font-family:Rubik,sans-serif;min-width:170px'><b>%s · %s</b><br><span style='color:#6f6790'>%s · %s</span><br><b>%s</b> species · <b>%s</b> / trap-night<br><a href='#' style='color:#7c52e0;font-weight:700' onclick=\"smtLoadStart('%s · loading…');Shiny.setInputValue('pickSite','%s',{priority:'event'});return false;\">\U0001F99F Explore this site &rarr;</a></div>",
                   d$site, d$name, d$blab, d$state, d$taxa, d$mos_per_tn %||% "—", gsub("'", "", d$name), d$site)
    leaflet::leaflet(d) %>% leaflet::addProviderTiles("CartoDB.Positron") %>% leaflet::setView(-96, 41, 3) %>%
      leaflet::addCircleMarkers(lng = ~lng, lat = ~lat, radius = ~rad, fillColor = ~bcol, color = "#fff", weight = 1, fillOpacity = 0.85,
        label = ~lapply(sprintf("<b>%s</b> · %s<br>%s · %s species", site, name, blab, taxa), htmltools::HTML), popup = pop) %>%
      leaflet::addLegend("bottomright", colors = unname(BIOME_COL), labels = unname(BIOME_LAB), title = "Biome", opacity = 0.9)
  })

  # ---- Across the continent: cross-site climate gradient (flagship) ---------
  output$climateGradient <- renderPlotly({
    g <- GRADIENT; if (is.null(g) || !nrow(g)) return(note_plot("Climate gradient unavailable. Run scripts/build_cross_site.R", "\U0001F30D"))
    unit <- input$tempUnit %||% "F"; xvar <- input$gradX %||% "temp"
    if (identical(xvar, "precip")) {
      g <- g[!is.na(g$monsoon_precip_mm) & (g$has_gauge %in% TRUE | is.na(g$has_gauge)), ]
      xcol <- "monsoon_precip_mm"; xlab <- "Warm-season precipitation (mm · NEON gauge)"; xsuf <- " mm"
    } else { xcol <- "warm_temp_c"; xlab <- sprintf("Warm-season air temperature (%s · NEON record)", temp_unit_lab(unit)); xsuf <- temp_unit_lab(unit) }
    tcom <- if ("t_used" %in% names(g)) g$t_used[1] else NA
    metric <- input$gradMetric %||% "index"
    yc <- switch(metric,
      index    = list(col = "mos_per_tn", lab = "Activity index (mosquitoes / trap-night)"),
      rarefied = list(col = "S_rare",     lab = sprintf("Species richness (rarefied to %s trap-nights)", ifelse(is.na(tcom), "equal", tcom))),
      observed = list(col = "taxa",       lab = "Species richness (observed, effort differs)"),
      culex    = list(col = "pct_culex",  lab = "Culex share (% of catch, West Nile group)"),
      hill1    = list(col = "hill_q1",    lab = "Common-species diversity (Hill q1)"),
      list(col = "mos_per_tn", lab = "Activity index (mosquitoes / trap-night)"))
    if (!yc$col %in% names(g)) yc <- list(col = "taxa", lab = "Species richness (observed)")
    g$xx <- suppressWarnings(as.numeric(g[[xcol]])); g$yy <- suppressWarnings(as.numeric(g[[yc$col]]))
    if (identical(xvar, "temp")) g$xx <- temp_val(g$xx, unit)
    g$eff <- suppressWarnings(as.numeric(g$trap_nights %||% g$collections)); g$eff[is.na(g$eff)] <- 1
    g <- g[is.finite(g$xx) & is.finite(g$yy), ]; if (!nrow(g)) return(note_plot("No sites with this combination", "\U0001F30D"))
    g$tip <- paste0("<span class='smt-pin-emoji'>\U0001F99F</span> <b>", g$site, " · ", g$name, "</b><br/>",
      "<em>", g$biome_lab, " · ", g$state, "</em><br/>",
      "<span class='smt-pin-stats'>", temp_disp(g$warm_temp_c, unit), " warm-season · ",
      ifelse(is.na(g$monsoon_precip_mm), "no precip gauge", paste0(g$monsoon_precip_mm, " mm monsoon")), "<br/>",
      g$taxa, " species · ", round(g$mos_per_tn, 2), " / trap-night<br/>",
      "top: <em>", g$top_taxon, "</em></span>",
      "<br/><span class='smt-open' role='button' tabindex='0' data-action='site' data-tag='", g$site, "'>\U0001F99F Open this site &rarr;</span>",
      "<br/><em class='smt-pin-hint'>Tap the dot to pin this card</em>")
    sref <- 2 * max(g$eff, na.rm = TRUE) / (26^2); muted <- if (is_dark()) "#9b91c0" else "#6f6790"
    p <- plot_ly()
    for (bm in unique(g$biome)) { sub <- g[g$biome == bm, ]
      p <- p %>% add_trace(data = sub, x = ~xx, y = ~yy, type = "scatter", mode = "markers", name = unname(BIOME_LAB[bm]),
        customdata = ~tip, text = ~paste0(site, " · ", name),
        marker = list(color = sub$biome_col[1], size = sub$eff, sizemode = "area", sizeref = sref, sizemin = 5,
                      opacity = 0.82, line = list(color = "#fff", width = 0.6)),
        hovertemplate = paste0("%{text}<br>%{x:.1f}", xsuf, " · %{y:.1f}<extra></extra>")) }
    if (!is.null(rv$site)) { ir <- g[g$site == rv$site, ]
      if (nrow(ir) == 1) p <- p %>% add_trace(x = ir$xx, y = ir$yy, type = "scatter", mode = "markers", name = "★ viewing", customdata = ir$tip,
        marker = list(symbol = "diamond", size = 18, color = "#e8920f", line = list(color = "#fff", width = 1.6)),
        hovertemplate = paste0("viewing ", ir$site, "<extra></extra>")) }
    rho <- suppressWarnings(stats::cor(g$xx, g$yy, method = "spearman")); n_sites <- nrow(g)
    ci_str <- ""
    if (is.finite(rho) && n_sites > 4 && abs(rho) < 1) {
      z <- atanh(rho); se <- 1.03 / sqrt(n_sites - 3); lo <- tanh(z - 1.96 * se); hi <- tanh(z + 1.96 * se)
      ci_str <- sprintf(", 95%% CI [%.2f, %.2f], n = %d", lo, hi, n_sites)
    } else if (is.finite(rho)) ci_str <- sprintf(", n = %d", n_sites)
    nshown <- if (nrow(g) < 46) sprintf("<b>%d of 46 NEON sites</b>", nrow(g)) else "<b>each of 46 NEON sites</b>"
    ann <- list(
      list(text = sprintf("Every dot is %s · %s × %s · dot size = trap-nights", nshown, if (xvar == "precip") "monsoon precip" else "warm-season temperature", tolower(yc$lab)),
           x = 0, y = 1.15, xref = "paper", yref = "paper", showarrow = FALSE, xanchor = "left", font = list(color = muted, size = 11)),
      list(text = sprintf("Spearman ρ = %.2f%s · space-for-time (46 places, not one site warming), correlational, confounded by biome &amp; latitude", ifelse(is.na(rho), 0, rho), ci_str),
           x = 0, y = 1.075, xref = "paper", yref = "paper", showarrow = FALSE, xanchor = "left", font = list(color = muted, size = 10.5)))
    p %>% plotly_theme() %>% plotly::layout(xaxis = list(title = list(text = xlab, standoff = 10)),
      yaxis = list(title = yc$lab, rangemode = "tozero"),
      annotations = ann, hovermode = "closest", margin = list(l = 60, r = 30, t = 96, b = 52))
  })

  # cross-site table download — the most analysis-ready frame (one tidy row per
  # site: climate + effort + the documented derived community metrics).
  output$crossSiteCsv <- downloadHandler(
    filename = function() sprintf("NEON-Mosquito_cross-site_%s.csv", format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      g <- GRADIENT
      if (is.null(g) || !nrow(g)) { utils::write.csv(data.frame(note = "Cross-site table unavailable; run scripts/build_cross_site.R."), file, row.names = FALSE); return() }
      keep <- intersect(c("site","name","state","biome_lab","warm_temp_c","mat_c","monsoon_precip_mm","precip_annual_mm","has_gauge",
                          "trap_nights","collections","taxa","mos_per_tn","S_obs","S_rare","t_used","coverage","hill_q1","hill_q2","mean_ubiquity","pct_culex","top_taxon","top_genus"), names(g))
      out <- g[, keep, drop = FALSE]
      if (isTRUE(ANY_SYNTHETIC)) out$DATA_NOTE <- "SYNTHETIC PLACEHOLDER — not measurements"
      utils::write.csv(out, file, row.names = FALSE, na = "") },
    contentType = "text/csv")

  # ---- About + help ---------------------------------------------------------
  output$aboutPanel <- renderUI({
    div(class="about-wrap",
      div(class="about-card", h4("\U0001F99F What this is"),
        p("An (unofficial) explorer for NEON's ", tags$b("Mosquitoes sampled from CO2 traps"), " (", tags$code("DP1.10043.001"), "). A CO2 trap releases carbon dioxide, the gas animals breathe out, and host-seeking female mosquitoes fly toward it. NEON sorts, weighs, and identifies the catch.")),
      div(class="about-card", h4(bs_icon("activity"), " Activity index, not population"),
        p("A CO2 trap measures host-seeking ", tags$b("activity"), ", not a headcount. Big catches are subsampled, so an identified count is scaled up to the whole trap by the ", tags$b("subsample weight ratio"), ", then divided by ", tags$b("trap-nights"), " (trapHours ÷ 24). The result is mosquitoes per trap-night, a ", tags$b("within-site index"), ", never a population."),
        p("Almost every mosquito in the catch is ", tags$b("female"), ", because only females bite and seek the CO2 plume. Read the sex split as a quality signal: a near-all-female catch is a normal, healthy trap.")),
      div(class="about-card", h4(bs_icon("calculator"), " How many species?"),
        p(tags$b("Chao2"), " (incidence-based) estimates how many species use the site beyond those caught. The sampling unit is a ", tags$b("collection occasion"), " (one trap-night), so revisits aren't double-counted. CO2 traps miss day-active and rare mosquitoes.")),
      div(class="about-card", h4(bs_icon("globe-americas"), " Across the continent"),
        p("NEON runs this protocol at ", tags$b("46 terrestrial sites"), ". The ", tags$b("Across the continent"), " tab places each site by its warm-season climate against its mosquito community. Deserts read against ", tags$b("monsoon rainfall"), " (the water that limits them); cooler sites against ", tags$b("degree-days"), " (the warmth that paces them)."),
        p("Richness is ", tags$b("rarefied to a common number of trap-nights"), " (Colwell et al. 2012). It is a ", tags$b("space-for-time"), " comparison, 46 places at once, not one place warming, so it is correlational, confounded by biome and latitude. Activity is a within-site index, so sites are compared by direction, never by who has the higher raw catch.")),
      div(class="about-card", h4(bs_icon("shield-exclamation"), " The vector angle"),
        p(tags$b("Culex"), " mosquitoes carry West Nile virus; in the western US ", tags$em("Culex tarsalis"), " is the main carrier, and it breeds fastest after the summer monsoon. This app shows ", tags$b("when and where"), " those mosquitoes are active. It does ", tags$b("not"), " test them for any virus, so activity is a heads-up, not a diagnosis or a risk measure.")),
      div(class="about-card", h4(bs_icon("envelope"), " Desert Data Labs"),
        p(bs_icon("envelope"), " ", tags$a(href="mailto:desertdatalabs@gmail.com","desertdatalabs@gmail.com"), " · ",
          tags$a(href="https://data.neonscience.org/data-products/DP1.10043.001", target="_blank", "NEON data product"))))
  })
  observeEvent(input$help, showModal(modalDialog(easyClose=TRUE, title=tagList(bs_icon("question-circle"), " How it works"),
    tags$ul(
      tags$li(HTML("Pick a <b>site</b> (or open the Santa Rita desert demo).")),
      tags$li(HTML("<b>The Pulse</b> · the seasonal activity curve against the monsoon, plus a Chao2 estimate of how many species use the site.")),
      tags$li(HTML("<b>Swarm Board</b> · every species by ubiquity × activity; <b>tap one</b> to pin its card, then “Open species profile”.")),
      tags$li(HTML("<b>Taxon Profile</b> · the sex split, yearly catch, data-quality flags, and downloads.")),
      tags$li(HTML("Counts are an <b>activity index</b> (per trap-night), not a population, and the catch is mostly host-seeking females."))),
    footer=modalButton("Got it"))))
}
