# Deploy — NEON Mosquito Pulse

Two surfaces, same as every suite sibling: the **cover** (static, GitHub Pages) and the **app** (Shiny, Posit Connect Cloud).

## 1. The cover (GitHub Pages)

`docs/index.html` is self-contained. In the repo's GitHub settings → Pages, serve from `master` / `/docs`. It will be live at:

```
https://tgilbert14.github.io/NEON-Mosquito-Pulse/
```

`docs/.nojekyll` is present so Pages serves the folder as-is.

### The app URL (set)

The cover's launch button + constellation core point at the live Connect Cloud app:

```
https://019ef0b1-0099-c999-1edc-4d47826044cc.share.connect.posit.cloud/
```

If you ever redeploy to a new share URL, replace it in **three places** in `docs/index.html` plus the README badge:
1. `var APP_URL = "…"` (top of the first `<script>`)
2. the `.launch` anchor `href`
3. the `.ccore` anchor `href`

(Every sibling's URL looks like `https://019e….share.connect.posit.cloud/`.)

## 2. The app (Posit Connect Cloud)

Connect Cloud is git-backed: it watches this repo and re-publishes on every push to `master`.

1. Make sure `data/` has bundles (run `scripts/build_synth_bundle.R` for the preview, or the real pipeline — see README).
2. Regenerate the manifest and commit it:
   ```r
   Rscript scripts/write_manifest.R
   ```
   **This is load-bearing.** Connect reads the committed `manifest.json`; if it is stale, the deploy restores the old package set or serves yesterday's data. Re-run it after any dependency or data change. `neonUtilities` is referenced only behind a split string + `requireNamespace`, so it stays out of the manifest and the deploy stays lean.
3. Push to `master`. Connect re-publishes; copy the share URL into the cover (step 1).

## 3. Auto-refresh

`.github/workflows/refresh-data.yml` runs the **first Saturday night each month** (Arizona time): a light environmental top-up + a cross-site precompute rebuild, then pushes to `master` (which triggers a Connect re-publish). The full 46-site mosquito re-pull is **on-demand** (`workflow_dispatch` → tick `refetch_mosquitoes`) because the product publishes on a lag. Add a `NEON_TOKEN` repo secret to raise the API rate limit.

## 4. Local preview

```r
shiny::runApp(".")              # the app
```
```bash
python -m http.server 8217 --directory docs   # the cover
```
(Both are wired in `.claude/launch.json` as `mosquito` and `cover`.)
