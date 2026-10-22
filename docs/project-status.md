# Project status

Last updated 2026-10-21.

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
  opens or updates one `data-refresh` issue, and stops. A person opens and
  merges the PR. The same workflow warns, and opens a `neon-release` issue,
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

- _Lead to fill in._

## Deliberately deferred

- Switching releases automatically. The workflow only reports a newer release.
- Opening or merging the refresh PR from the workflow. A person does both.
- _Lead to add further deferrals._
