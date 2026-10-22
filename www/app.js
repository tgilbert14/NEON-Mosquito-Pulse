/* adapted from NEON-Breeding-Birds@4805cb5; diverged locally */
/* =========================================================================
   app.js: count-up stat counters, the loading overlay, popover dismissal,
   keyboard access for QC flags, and the Shiny custom message handlers.
   ========================================================================= */

// When a tab becomes visible, nudge a resize so widgets that rendered while the
// tab was hidden (Leaflet maps, plotly charts) re-fit to their real size: the
// classic "0-sized widget in a hidden bootstrap tab" fix.
document.addEventListener("shown.bs.tab", function () {
  setTimeout(function () { try { window.dispatchEvent(new Event("resize")); } catch (e) {} }, 60);
});

// ---- animated count-up for the hero stat band ----------------------------
function animateCount(el) {
  if (el.dataset.animated === "1") return;
  el.dataset.animated = "1";
  // A freshly-rendered hero counter means a site just finished loading, the
  // most reliable signal to dismiss the loading overlay (no reliance on a
  // custom Shiny message, which doesn't always register in time).
  if (typeof smtLoadDone === "function") smtLoadDone();
  const target = parseFloat(el.getAttribute("data-target")) || 0;
  const suffix = el.dataset.suffix || "";          // e.g. "d", "m", "g"
  const isFloat = !Number.isInteger(target);
  const fmt = (v) => (isFloat ? v.toFixed(1) : Math.round(v).toLocaleString()) + suffix;
  // reduced-motion: snap to the final value, no animation
  if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    el.textContent = fmt(target); return;
  }
  const dur = 900;
  const start = performance.now();
  function tick(now) {
    const t = Math.min(1, (now - start) / dur);
    const eased = 1 - Math.pow(1 - t, 3); // easeOutCubic
    el.textContent = fmt(target * eased);
    if (t < 1) requestAnimationFrame(tick);
    else el.textContent = fmt(target);
  }
  requestAnimationFrame(tick);
}

function runCounters() {
  document.querySelectorAll(".count-up").forEach(animateCount);
}

// Re-run whenever Shiny injects fresh stat cards.
const heroObserver = new MutationObserver(() => runCounters());
document.addEventListener("DOMContentLoaded", function () {
  const host = document.body;
  heroObserver.observe(host, { childList: true, subtree: true });
  runCounters();
});

// ---- loading overlay (opaque, indeterminate) -----------------------------
// A site load is one synchronous blocking call whose duration we can't know,
// so we show an INDETERMINATE animated bar (no fake %) on an OPAQUE backdrop:
// it just spins until the server signals it's done. No number to "stall" at,
// and you don't see half-rendered data through it.
var smtSafetyTimer = null;
function smtLoadStart(label) {
  var ov = document.getElementById("loadOverlay");
  if (!ov) return;
  // Raise the overlay IMMEDIATELY, synchronously, on the click. A site load is
  // 1-3 s of BLOCKING work on the worker (decompress + clean + leaderboard + the
  // Overview tab's plotly renders). A server-sent "show" message can't paint
  // until that block ends, which is too late, so the overlay is shown
  // client-side right now. (Loads are never truly instant, so the old 250 ms
  // defer just hid the feedback during exactly the freeze it's for.)
  var siteText = label || "";
  if (!siteText) {
    var sel = document.getElementById("site");
    if (sel && sel.options && sel.selectedIndex >= 0) siteText = sel.options[sel.selectedIndex].text;
  }
  var siteEl = document.getElementById("loadSite");
  if (siteEl) siteEl.textContent = siteText;
  ov.style.display = "flex";
  if (navigator.vibrate) { try { navigator.vibrate(12); } catch (e) {} }  // tactile "got it"
  clearTimeout(smtSafetyTimer);
  smtSafetyTimer = setTimeout(function () {  // safety net so it can never stick
    var note = document.querySelector(".load-note");
    if (note) note.textContent = "This site is taking longer than usual. This screen will clear in a moment; pick the site again if the data does not appear.";
    setTimeout(smtLoadDone, 5000);
  }, 90000);
}
// Scroll-free on purpose: this also runs from the count-up, the 90 s safety
// timer and every failure path. The post-load scroll + focus lives in the
// loadDone handler below and only runs on {ok: true}.
function smtLoadDone() {
  clearTimeout(smtSafetyTimer);
  var ov = document.getElementById("loadOverlay");
  if (ov) ov.style.display = "none";
}

// ---- after a successful load: hero to the top, focus on the hero band -----
// On a phone the picker sits 2,000-3,000 px down the splash; without this the
// loaded site opens mid-page. The hero sits just under the top bar, so the
// page goes to the top now and again once the hero has rendered.
var smtHeroFocusOff = null;
function smtFocusHeroOnNextRender() {
  if (!window.jQuery) return;
  if (smtHeroFocusOff) smtHeroFocusOff();
  var expiry = null;
  var handler = function (e) {
    if (e.name !== "heroStats") return;
    smtHeroFocusOff();
    // shiny:value fires before the new HTML is in the DOM; wait one frame
    setTimeout(function () {
      var band = document.querySelector("#heroStats .hero-band");
      window.scrollTo(0, 0);   // the hero sits just under the top bar; re-measure once it has rendered
      if (!band) return;
      band.setAttribute("tabindex", "-1");
      try { band.focus({ preventScroll: true }); } catch (err) { band.focus(); }
    }, 0);
  };
  smtHeroFocusOff = function () {
    jQuery(document).off("shiny:value", handler);
    clearTimeout(expiry);
    smtHeroFocusOff = null;
  };
  jQuery(document).on("shiny:value", handler);
  // one-shot: if the hero never re-renders for this load, stop listening
  expiry = setTimeout(function () { if (smtHeroFocusOff) smtHeroFocusOff(); }, 15000);
}
function smtScrollToHero() {
  requestAnimationFrame(function () {
    window.scrollTo(0, 0);
  });
}

// (The site report card is a server-side PDF streamed by the Shiny
//  downloadHandler output$reportPdf; there is no browser-print path here.)

// (The driver.js guided tour from the sibling apps was removed: driver.js is not
//  loaded here and its steps referenced UI this app doesn't have. The
//  "How it works" modal covers onboarding instead.)

// ---- dismiss any open info popover (click-outside + Esc) -----------------
// bslib/Bootstrap popovers don't close on an outside click by default, so make
// every "ⓘ" popover dismissible the way users expect.
function smtClosePopovers() {
  document.querySelectorAll(".popover").forEach(function (pop) {
    var trig = pop.id ? document.querySelector('[aria-describedby="' + pop.id + '"]') : null;
    if (trig && window.bootstrap && bootstrap.Popover) {
      var inst = bootstrap.Popover.getInstance(trig);
      if (inst) { inst.hide(); return; }
    }
    pop.remove(); // fallback: just remove the floating popover
  });
}
document.addEventListener("click", function (e) {
  if (e.target.closest(".popover") || e.target.closest(".info-dot") ||
      e.target.closest("bslib-popover")) return;        // clicking inside/trigger -> leave it
  if (document.querySelector(".popover")) smtClosePopovers();
});
document.addEventListener("keydown", function (e) {
  if (e.key === "Escape") smtClosePopovers();
});
// QC flags are div[role=button][tabindex=0] with an inline onclick: give them
// the native button keys (Enter and Space activate; Space must not scroll).
document.addEventListener("keydown", function (e) {
  if (e.key !== "Enter" && e.key !== " " && e.key !== "Spacebar") return;
  var el = e.target && e.target.closest && e.target.closest('.qc-flag-click[role="button"]');
  if (!el || e.repeat) return;
  e.preventDefault();
  el.click();
});

// ---- Shiny custom message handlers ---------------------------------------
document.addEventListener("DOMContentLoaded", function () {
  if (window.Shiny) {
    Shiny.addCustomMessageHandler("countUp", function (_msg) {
      // small delay so the freshly-rendered DOM is in place
      setTimeout(runCounters, 60);
    });
    Shiny.addCustomMessageHandler("loadDone", function (msg) {
      smtLoadDone();
      if (msg && msg.ok) {
        smtFocusHeroOnNextRender();
        smtScrollToHero();
      }
    });
    // server-triggered overlay (e.g. a click on the national picker map, which
    // has no inline onclick to call smtLoadStart directly)
    Shiny.addCustomMessageHandler("smtLoadStart", function (msg) {
      smtLoadStart(msg && msg.label);
    });
    // A Leaflet map that initialised inside a hidden tab/container (the Plot-map
    // tab, or the picker map re-shown after "change site") can paint blank until
    // it recomputes its size. Dispatching 'resize' makes every Leaflet map
    // invalidateSize. The server kicks this after re-showing the splash.
    Shiny.addCustomMessageHandler("kickMaps", function (_msg) {
      var kick = function () { try { window.dispatchEvent(new Event("resize")); } catch (e) {} };
      requestAnimationFrame(kick);
      [80, 250, 500, 900].forEach(function (t) { setTimeout(kick, t); });
    });
  }
});
