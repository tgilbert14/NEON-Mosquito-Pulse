# Project status

Last updated 2026-10-22.

## Current state

- The app is live on Posit Connect Cloud, published from `master`:
  <https://019ef0b1-0099-c999-1edc-4d47826044cc.share.connect.posit.cloud/>.
  The cover is on GitHub Pages: <https://tgilbert14.github.io/NEON-Mosquito-Pulse/>.
- Data: NEON DP1.10043.001, RELEASE-2026 (DOI 10.48443/rmw1-me46, CC BY 4.0),
  47 field sites, data through 2024-12. The pinned release is named once, in
  `R/mos_release.R`.
- The bundles were rebuilt after the `samplingImpractical = OK` fix, which counts
  those periods as sampled (PR #14).
- Refresh: `.github/workflows/refresh-data.yml` runs on the first Saturday of the
  month. It validates the candidate, pushes `automation/mosquito-release-2026`,
  and stops. When the candidate changes data, a `notify` job opens or updates
  one `data-refresh` issue with a rows and data-through summary; a change to
  checksums alone opens none. A person opens and merges the PR. The same workflow warns, and opens a `neon-release` issue,
  when NEON lists a release newer than the pinned one, and lists NEON issue-log
  entries dated after the pinned release.
- Post-deploy: `scripts/post_deploy_smoke.sh` requires the Pages poster marker
  and a Connect page whose `neon-app-revision` meta matches the md5 of the
  merged `manifest.json`.

## Open items

- Set the Connect content variable `CARTO_BASEMAP_KEY` if it is not set, then
  confirm the national map loads tiles from `basemaps.cartocdn.com`
  (`DEPLOY.md` step 7).
- RELEASE-2027: when NEON publishes it, the release watch opens an issue. Moving
  to it is a reviewed change to `R/mos_release.R` plus a full rebuild through
  the review branch.

## This round (2026-10)

- Closed the 2026-10-18 suite audit findings for this app (status file:
  `neon-audit-2026-10-18/reports/status/mosquito.md` outside the repo).
- Bundle schema `mosquito-pulse-opportunity-v2`: rate denominators use
  resolved effort; intervals whose catch is pending, held or unknown are
  counted and shown, never read as zero.
- New on screen: catch per 24 trap-hours by year, a peak week that names the
  years behind it, a site data-quality card, the report PDF, the suite
  registry and codebook in About, `?site=` links, a working species card PNG.

## Deliberately deferred

- Switching releases automatically. The workflow only reports a newer release.
- Opening or merging the refresh PR from the workflow. A person does both.
- Two-week bins for the Pulse. NEON bouts are biweekly, so each week of the
  year is trapped in about half the years; the headline names that support
  instead. Changing the bin is a methods call for fauna.
- Separate night-only and day-only indices (new scope for fauna and the lead).
- Checking record SRER_041.20200116.0803 against `mos_sorting` (needs a NEON
  token and fauna's verdict); after the rebuild it is 10% of the SRER catch,
  under the 25% note threshold.
