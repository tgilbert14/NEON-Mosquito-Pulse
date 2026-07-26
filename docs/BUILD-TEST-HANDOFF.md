# Mosquito Pulse build and test handoff

## 2026-07-26 · Pass 6 foundation (America/Phoenix)

### Scope

Release/manifest and scientific-contract audit; opportunity-complete effort and zero-catch rebuild; static Living Poster on Pages and in the app; responsive/accessibility QA; safe refresh and production gates.

### Baseline

- Repository default branch: `master`.
- Baseline revision: `f640a35b11fb52afe6f4c04853a6a15f245a3fc4`.
- Existing committed roster: 46 sites; RELEASE-2026 canonical roster: 47 (PUUM missing).
- Existing manifest: 91 packages, 107 files, seven tracked checksum mismatches, moving package sources.
- Only workflow wrote refreshed bytes directly to `master`, could succeed without rebuilding, and accepted a partial ≥30-site pull.
- Existing effort key was `plotID × collectDate`; this could collapse day and night intervals.
- Invalid/missing `proportionIdentified` silently became 1×.
- Site activity was derived from species-level rows despite documentation promising coarser target catch in the total.
- Pages and app first screen used animated/remote-dependent presentation rather than the suite's final static Living Poster.

### Implemented on review branch

- Branch: `agent/mosquito-pass6-foundation`.
- Foundation commit: `56eae0d`.
- RELEASE-2026 producer/validator run: `30206874424` (in progress at this entry).
- Added exact opportunity/outcome contract in `R/mos_bundle_contract.R` and executable fixtures in `scripts/test_helpers.R`.
- Added 47-site staging, source receipts, strict bundle/manifest verification, pinned CI, review-only refresh publication, and semantic production smoke tests.
- Added static local Living Poster art to Pages and the Shiny landing, with provenance and fixed SHA-256 checks.
- Removed remote fonts/CDNs from app startup and removed the tracked scratch artifact `50`.

### Local checks completed

- `node --check www/app.js`
- `node --check www/pincards.js`
- `node scripts/check_custom_message_handlers.mjs`
- `node scripts/check_cover.mjs`
- `bash -n scripts/post_deploy_smoke.sh`
- `ruby` YAML parse for all workflow files
- `git diff --check`

All completed successfully. R 4.5.2 is not installed locally; GitHub's pinned Jammy validator is authoritative.

### Required closeout

1. Wait for run `30206874424`; fix source/schema failures without weakening gates.
2. Bring the exact validated 47-site artifact onto the final review branch.
3. Generate and commit the exact validated manifest.
4. Run desktop/mobile Pages and app QA, keyboard/focus checks, and semantic production checks.
5. Open a ready PR, require green exact-head CI, merge, verify exact merge CI/Pages/Connect, and record hashes/counts here.
6. Update the Driver register and implication backlog without rebuilding Driver artifacts.

### Residual boundaries

- Climate overlays remain available for the prior 46-site environmental set; PUUM is held from climate-gradient placement until an equivalent pinned overlay is available.
- `DP1.10043.001` contains mosquito catches, not pathogen test results. No infection or risk inference is supported.
