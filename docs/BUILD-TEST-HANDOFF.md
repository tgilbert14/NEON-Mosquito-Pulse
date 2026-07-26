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

## 2026-07-26 · Passes 6–8 production closeout (America/Phoenix)

### Release result

- Production revision: `935420e1e1aa79dcc3cf54d03ef150f6f0332b8d` on `master`.
- Foundation PR: [#3](https://github.com/tgilbert14/NEON-Mosquito-Pulse/pull/3), exact head `c1c0783eb762b3c97361f3e1b476caf06c9d34a4`, merge `1522048ed76d16f4d34ece6b2c2c946153bc48b0`.
- Runtime lifecycle hotfix PR: [#4](https://github.com/tgilbert14/NEON-Mosquito-Pulse/pull/4), exact head `c909ef2fe3de32af631bd70bf71bfa278448fe05`, merge `68aef412015c6ffb4856cb64e2b132a59a762e7b`.
- Interaction-target polish PR: [#5](https://github.com/tgilbert14/NEON-Mosquito-Pulse/pull/5), exact head `24e0eb745691c68707951a2d32706e2a505de197`, merge `935420e1e1aa79dcc3cf54d03ef150f6f0332b8d`.
- Live Pages: <https://tgilbert14.github.io/NEON-Mosquito-Pulse/>.
- Live Connect app: <https://019ef0b1-0099-c999-1edc-4d47826044cc.share.connect.posit.cloud/>.

### Immutable release and manifest evidence

- Exact empty-staging RELEASE-2026 producer/validator run: `30207972162`.
- Validator artifact: 47 site bundles; 223,048 combined effort/catch rows; 55,114 valid opportunities; 25,076 supported zero catches; 103,887 catch rows; 82,875 held rows.
- Validated data artifact SHA-256: `2679408c4af5387811f2b3ac12642ea22b962fd996c855eb9216e0545838f3ed` (artifact `8634540770`).
- Source receipt: 47 site rows plus header; SHA-256 `00bba55dcfa4fdba2f9f9400e53cbff319d3a9281eacd6fb32e7b533aaa4f826`.
- Final Connect manifest: R 4.5.2, 91 pinned packages, 112 runtime files; SHA-256 `acef14509ce44347d53a99b252cd92814797df1698b5a4365c9e0ac0724cc4ce`.
- Integrated-head no-download refresh reproduction: run `30211449455`, all producer/validator/publisher jobs passed with no release-byte diff.
- The exact producer and validator succeeded in run `30207972162`; its overall run was red only because the default Actions token could not open the review PR after safely publishing `automation/mosquito-release-2026`. The publisher now treats that permission boundary as a successful safe branch publication and emits a notice.

### Exact CI and deployment evidence

- Foundation PR CI `30211462476`; merge CI `30212048494`; Pages `30212048059`; production smoke `30212048468`: passed.
- Runtime hotfix PR CI `30212805885`; merge CI `30212882395`; Pages `30212882153`; production smoke `30212882466`: passed.
- Final accessibility PR CI `30213142660`; merge CI `30213225754`; Pages `30213225369`; production smoke `30213225753`: passed on exact `935420e`.
- CI parses all R/JS, runs opportunity/zero/expansion contracts, regenerates and compares the exact manifest, verifies all bundles/indexes/receipts, sources the app offline, and renders SRER through `shiny::testServer()`.

### Browser and accessibility evidence

- Pages passed 1440, 768, 390, and 320 px checks with no horizontal overflow, no cover animation, one Driver route, one primary CTA, local art, and descriptive figure text.
- Pages markers and app markers are `mosquito-pulse-poster-v1` and `mosquito-pulse-v1`.
- At 390 px, a fresh production Connect session had zero `.shiny-output-error` nodes before selection and after opening SRER; the page remained 375 CSS px wide with no overflow.
- SRER rendered 18 species, 1,075 rounded 24-hour effort units, activity-index boundaries, and the explicit no-pathogen/no-health-risk statement.
- The 19 audited loaded-view controls (change/report, info popovers, tabs, and expand controls) all measured at least 44 × 44 CSS px in final production.
- Skip link, landmark/heading structure, descriptive image alternative, reduced-motion rules, visible high-contrast focus outlines, and 44 px cover controls were checked. No remote font or CDN is required to boot.

### Failure found and corrected during acceptance

The first production browser pass found `heroStats` and `siteInsights` in generic Shiny error states even though the shell and semantic marker loaded. Both outputs ran before a site bundle existed. PR #4 added explicit pre-load reactive guards and a permanent regression that requires quiet pre-load suspension plus successful real-bundle output rendering. Acceptance resumed only after a fresh production session passed both states.

### Art provenance

- Source PNG SHA-256: `120e4397b5ab74c3b9c2d1636568e5904fe0268b1f4cad9a77f86941ecf14581`.
- Pages/app WebP SHA-256: `aa6098780e1029cf4beb1d3afe967ac42a102e05df1c1f0afbf752520138e110`.
- Social image SHA-256: `3ac459d280f2703ba80ed92ed31a102781601ab15e85437476f4d2239598fd11`.
- The complete generation prompt, selection rationale, derivation chain, and file hashes are locked in `docs/ART-PROVENANCE.md`.

### Residual boundary and next action

- **HOLD:** PUUM remains eligible throughout the mosquito app but is excluded from climate-gradient placement until an equivalent pinned climate overlay exists.
- Next action: update the Driver Cascade register and implication backlog with this exact evidence without changing Driver release artifacts.
