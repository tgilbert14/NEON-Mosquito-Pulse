# NEONize playbook — Mosquito Pulse

How this app was built to the suite's gold standard, and the rules that keep it honest. (Companion to `DATA-TAKEAWAYS.md`.)

## The shape (ported one-for-one from the Breeding Birds sibling)

- **Chrome:** shared `www/styles.css` (never edited per app) + a per-app accent layer `www/mosquito.css` that overrides the same `:root` tokens, so cards/tables/popovers re-theme for free. Accent: **"Monsoon Nightstorm"** — storm-violet night, an electric "swarm" lime as the data/energy colour, a monsoon-amber reserved exclusively for the West Nile / Culex note.
- **Bundle:** per-site `list(obs, traps, meta)` → precomputed `data/site_index.rds`, `data/cross_site.rds`, `data/site_climate.rds`, `data/site_month_clim.rds`, loaded once at boot.
- **Flow:** national picker map → per-site tabs → pinnable plotly cards (`www/pincards.js`) → PNG/CSV exports → clickable + downloadable QC flags.
- **Self-deploy:** Connect Cloud git-backed; monthly off-peak `refresh-data.yml`; lean manifest (neonUtilities excluded behind a split string).

## The locked data palettes (data, never theme)

`GENUS_COL` (Culex amber, Aedes violet, Anopheles teal, Culiseta olive, Psorophora rose, other grey) and `SEX_COL` (female violet, male teal, undetermined grey) live as literal R vectors in `global.R`. They are never read from a CSS token, exactly as the bird app locks its sing/call/visual palette. Lime never appears as in-app text or chrome — only as plot marks and the hero glow.

## The one builder

`bundle_mos_data.R` is the **single** producer of the trap-night activity index and `site_index.rds`. The app never recomputes a divergent denominator (the CPUE-vs-MNKA trap). Pick **mosquitoes per trap-night** once, label it a within-site index everywhere, regenerate `manifest.json` after any change or Connect serves stale.

## The honest claims (and the refusals)

The Overview banner is **biome-conditional**: deserts read against the **monsoon precip** pulse, cooler sites against **degree-days**, never a monotone "warmer = more" in the desert (the extreme-heat ceiling). It states **direction, not magnitude**, never "drives"/"causes," always carries the within-site-index disclaimer, and **refuses**: absolute populations, cross-site magnitude ranking, population sex ratio, disease/WNV risk, and any green-up→mosquito or mosquito→vertebrate trophic edge (no measured mechanism).

## Where it sits in the cascade

Mosquitoes are a **second climate-driven trigger**, parallel to temp→green-up: the desert-water mirror of the temperate-warmth story. For the cross-product `NEON-Driver-Cascade`, they enter as two **same-year (lag 0)** annual priors — `precip_monsoon→mosq_activity` (water-limited) and `temp_spring→mosq_activity` (temperature-limited) — a coarse annual echo of the weekly within-season pulse this app shows directly. Pooling is mandatory (one sign-vote per site, `binom.test`, min 3 gauge-sites); annual per-site verdicts are underpowered and stay exploratory.

## The preview-data contract

With no live fetch available, `build_synth_bundle.R` ships **deterministic, clearly-labelled synthetic** bundles (`meta$synthetic = TRUE`) so the app and cover render real-looking, biome-conditional numbers. The app shows a persistent "preview build" banner whenever a synthetic bundle is loaded. The real pipeline overwrites them and the banner disappears.
