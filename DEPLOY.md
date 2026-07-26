# Deployment

Production is driven by the watched `master` branch.

1. Build and validate on a review branch with R 4.5.2, Ubuntu 22.04, the dated 2026-07-15 package snapshot, and the pinned geospatial closure.
2. Generate `manifest.json`; never edit it manually.
3. Confirm exact-head CI, bundle/source receipt, Pages marker, and local visual/accessibility review.
4. Merge the ready PR into `master`.
5. Wait for exact-merge CI, GitHub Pages, and Posit Connect Cloud.
6. Require `mosquito-pulse-poster-v1` on Pages and `mosquito-pulse-v1` from Connect. HTTP 200 is not sufficient.

The monthly refresh uses producer → validator → restricted publisher jobs and opens a PR. It never pushes data directly to production.

Production URLs:

- Pages: https://tgilbert14.github.io/NEON-Mosquito-Pulse/
- Connect: https://019ef0b1-0099-c999-1edc-4d47826044cc.share.connect.posit.cloud/
