# NEON Mosquito Pulse

An explorer for NEON's **Mosquitoes sampled from CO2 traps** (`DP1.10043.001`) — the ninth app in the Desert Data Labs **NEON Explorer Suite**, and its first arthropod-vector rung.

> **The desert monsoon sets off a mosquito pulse.** When the summer rains arrive, standing water appears and, two to six weeks later, adult mosquitoes emerge, paced by how warm those weeks are. This app lets you watch that pulse inside a single desert site, and place it against the whole NEON network in climate space. It is the water-limited mirror of the suite's other climate trigger, the spring warmth that wakes the plants.

**Cover (GitHub Pages):** https://tgilbert14.github.io/NEON-Mosquito-Pulse/
**App (Posit Connect Cloud):** _set after first deploy — see [DEPLOY.md](DEPLOY.md)_

---

## What it shows

A national map of 46 NEON sites, then per site:

| Tab | What it does |
|---|---|
| **Overview** | The most-active species (coloured by genus), a plain-English summary, and a genus + sex composition strip. |
| **The Pulse** | The signature chart: the weekly activity curve with the site's summer-monsoon window shaded behind it, plus species accumulation and a Chao2 richness estimate. |
| **Swarm Board** | Every species as a dot, **ubiquity × activity index**, Culex flagged. Tap to pin a downloadable card. |
| **Across the continent** | Every NEON site in climate space (monsoon rain for deserts, degree-days for cooler sites) against its mosquito community. Space-for-time, stated on the chart. |
| **Taxon Profile** | A downloadable card (PNG + CSV): activity index, ubiquity, the **sex split**, yearly catch, and clickable, downloadable data-quality flags. |
| **Map** | CO2-trap grids across the site; tap a grid for its species list. |
| **About** | Methods, the honest-index framing, and the One-Health / West Nile context. |

## The honesty discipline (shared with the suite)

- **Abundance is a within-site _activity index_** (mosquitoes per trap-night), never a population. A CO2 trap measures host-seeking effort.
- **The catch is mostly female by design.** CO2 traps lure host-seeking females; a near-all-female catch is the method working, not a population sex ratio.
- **Big catches are weight-scaled.** NEON identifies a weighed subsample of a huge night; the count is scaled up to the whole trap by the subsample weight ratio, then divided by trap-nights.
- **Cross-site is space-for-time** — 46 different places watched at once, correlational, confounded by biome and latitude. Compare sites by direction, never by who has the higher raw catch.
- **Culex activity is a heads-up, not a risk.** This product is _abundance_; whether a mosquito carries a virus is a separate NEON program. The app never translates a catch into disease risk.
- **Every chart states how its number was made.**

## Run it locally

```r
# from the repo root
shiny::runApp(".")
```

The app reads only the committed `data/` bundles, no live fetch at runtime.

### Preview data (this build)

There is no R toolchain shipped with this repo, so the committed `data/` starts as **representative synthetic placeholder catches** so the app and cover render real-looking numbers. They are clearly labelled (a banner in the app + cover) and are **not measurements**. Regenerate them any time with:

```r
Rscript scripts/build_synth_bundle.R
```

### Real NEON data

```bash
# 1. pull the raw product for every site (R-4.1.1; resumable)
Rscript scripts/fetch_mos_all.R
# 2. bundle to per-site list(obs, traps, meta) + data/site_index.rds  (the single builder)
Rscript scripts/bundle_mos_data.R
# 3. precompute the cross-site gradient table
Rscript scripts/build_cross_site.R
# 4. regenerate the deploy manifest (or Connect serves a stale package set)
Rscript scripts/write_manifest.R
```

Running the real pipeline overwrites the synthetic bundles; `meta$synthetic` drops away and the preview banner disappears automatically.

## Data product

NEON [Mosquitoes sampled from CO2 traps (`DP1.10043.001`)](https://data.neonscience.org/data-products/DP1.10043.001). Tables joined: `mos_trapping` (effort / trap-nights), `mos_sorting` (subsample weights), `mos_expertTaxonomistIDProcessed` (the identified counts).

Data: National Ecological Observatory Network (operated by Battelle, funded by NSF). **Not affiliated with NEON, Battelle, or the NSF.** An educational data-exploration tool by [Desert Data Labs](https://desertdatalabs.com), Tucson, AZ.
