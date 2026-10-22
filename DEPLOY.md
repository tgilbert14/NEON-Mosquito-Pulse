# Deployment

Production is driven by the watched `master` branch.

1. Build and validate on a review branch with R 4.5.2, Ubuntu 22.04, the dated 2026-07-15 package snapshot, and the pinned geospatial closure.
2. Generate `manifest.json`; never edit it manually.
3. Confirm exact-head CI, bundle/source receipt, Pages marker, and local visual/accessibility review.
4. Merge the ready PR into `master`.
5. Wait for exact-merge CI, GitHub Pages, and Posit Connect Cloud.
6. `scripts/post_deploy_smoke.sh` (run by `post-deploy.yml` on every push to `master`) requires `mosquito-pulse-poster-v1` on Pages, and from Connect a `<meta name="neon-app-revision">` whose content equals the md5 of the merged `manifest.json`, plus `<title>NEON Mosquito Pulse</title>` and `<html lang="en">`. A matching revision proves Connect rebuilt from this commit; an older bundle that answers HTTP 200 fails. The check retries every 30 s and fails after 45 minutes (a Connect source rebuild can take a while).
7. Set the Connect content variable `CARTO_BASEMAP_KEY` in the Connect Cloud content settings. It is a public, referrer-restricted tile key and never goes in git. After the deploy, open the national map and confirm the browser requests tiles from `basemaps.cartocdn.com`.

The monthly refresh uses producer, validator and restricted publisher jobs. The publisher pushes the validated candidate to `automation/mosquito-release-2026`, writes a change summary from the source receipts (rows per site, data through), and stops. When the candidate changes data, a separate `notify` job opens or updates one `data-refresh` issue with the summary and the compare link; a change to checksums alone opens no issue. A person opens the PR, checks the exact head, and merges. The workflow never pushes to `master` and never opens a PR.

Production URLs:

- Pages: https://tgilbert14.github.io/NEON-Mosquito-Pulse/
- Connect: https://019ef0b1-0099-c999-1edc-4d47826044cc.share.connect.posit.cloud/
