# NEON Mosquito Pulse

An unofficial, art-forward explorer for NEON **Mosquitoes sampled from CO₂ traps** (`DP1.10043.001`). The production bundle is pinned to **RELEASE-2026**, DOI **10.48443/rmw1-me46**, across 47 terrestrial sites.

- [Living Poster / GitHub Pages](https://tgilbert14.github.io/NEON-Mosquito-Pulse/)
- [Interactive Shiny app](https://019ef0b1-0099-c999-1edc-4d47826044cc.share.connect.posit.cloud/)
- [Suite hub](https://tgilbert14.github.io/NEON-Driver-Cascade/)

## What is measured

The headline metric is eligible whole-trap-scaled mosquitoes per 24 trap-hours. It is a within-site trap-activity index—not population abundance, density, infection, transmission, exposure, or health risk.

The bundle is opportunity-complete:

- daytime and nighttime intervals remain separate;
- valid `targetTaxaPresent = N` intervals are supported zeros;
- missed, unknown, pending, or held outcomes are not zeros;
- invalid subsample proportions are held rather than treated as 1×;
- coarse target IDs remain in total activity but cannot inflate species richness.

See [the scientific contract](docs/SCIENCE-CONTRACT.md) and [pre-release review](docs/EXPERT-REVIEW.md).

## Local app

The deployed app runs entirely from committed bundles and local assets. With R 4.5.2 and the runtime packages installed:

```r
shiny::runApp()
```

No NEON request, CDN, or font download occurs at startup.

## Build and verification

The authoritative build runs in pinned GitHub Actions. Core commands are:

```bash
Rscript --vanilla scripts/test_helpers.R
Rscript --vanilla scripts/fetch_mos_all.R
Rscript --vanilla scripts/bundle_mos_data.R
Rscript --vanilla scripts/build_climate.R
Rscript --vanilla scripts/build_cross_site.R
Rscript --vanilla scripts/build_search_index.R
Rscript --vanilla scripts/write_manifest.R
Rscript --vanilla scripts/verify_bundle.R
node scripts/check_cover.mjs
```

The refresh workflow builds all 47 sites in empty staging, validates the exact candidate, and opens a review PR. It cannot push unchecked data to `master`.

## Data and art provenance

- Source receipt: `data/source-receipt.csv`
- Bundle contract: `R/mos_bundle_contract.R`
- Image prompt and hashes: `docs/ART-PROVENANCE.md`
- Operational handoff: `docs/BUILD-TEST-HANDOFF.md`

NEON data are publicly available from the [official product page](https://data.neonscience.org/data-products/DP1.10043.001/RELEASE-2026). This project is not an official NEON product.
