# Driver knowledge package · Mosquito Pulse

## Decision

**ADOPT** — The suite should adopt outcome-state reconciliation for every opportunity-complete sampling product: positive, supported zero, unavailable/unknown, held, and ineligible are distinct states before aggregation.

## Evidence

- `sampleID` is an outcome linkage and can be absent when the trap contains no target mosquitoes.
- `plotID × collectDate` is not a safe interval key because day and night samples can share a plot/date.
- NEON's `uid`, or a full event/plot/set/collect/day-night composite, preserves physical interval identity.
- A positive-catch-only denominator and a zero-catch-only fix both remain incomplete unless pending/held outcomes are represented separately.
- Coarse target identifications belong in total activity but not species richness.
- Subsample expansion must fail closed when the proportion is not in `(0, 1]`.

## Eligible joins

`mos_trapping effort interval` ←(`sampleID`, optional on zero catch)→ `mos_sorting` ←(`subsampleID`)→ `mos_expertTaxonomistIDProcessed`

The leftmost effort table owns identity, validity, and duration. Downstream catch rows cannot create opportunities.

## Engineering learning

- Separate producer, validator, and restricted publisher jobs. Only the publisher writes, and it opens/updates a review PR.
- Exact site rosters are release contracts. Numeric minimum thresholds are not.
- A release receipt needs product, release, DOI, generation date, per-site row counts, and raw digest.
- Keep build-only download packages outside the deploy manifest.
- Static cover art should be local, checksum-locked, labeled as illustration, and reused between Pages and the app.
- Semantic ready markers make deployment health testable; HTTP 200 alone is insufficient.

## Suite implication

Audit other sampling apps for a binary catch/absence model that lacks pending/held states. Opportunity completeness is not only “add zero rows”; it is explicit outcome reconciliation at the physical sampling grain.

## Production disposition · 2026-07-26

**ADOPT** — The outcome-state reconciliation and restricted producer/validator/publisher pattern are production-proven at 47 sites. The exact release contains 55,114 valid opportunities, including 25,076 supported zeros; unavailable, held, and ineligible states never enter that zero claim.

**CONTEXT** — Semantic HTTP markers prove that the intended shell is reachable, not that hidden reactive outputs render. Add one real-bundle `shiny::testServer()` render to every Shiny app's exact-head gate, and browser-check an initially hidden output both before and after it becomes visible. This release caught and fixed that distinction in PR #4.

**HOLD** — Do not place PUUM on the climate gradient until an equivalent pinned environmental overlay is available. Its RELEASE-2026 mosquito bundle remains valid for every non-climate view.

### Exact evidence

- Production revision: `935420e1e1aa79dcc3cf54d03ef150f6f0332b8d`.
- Release validator run: `30207972162`; artifact SHA-256 `2679408c4af5387811f2b3ac12642ea22b962fd996c855eb9216e0545838f3ed`.
- Final manifest: R 4.5.2, 91 packages, 112 runtime files; SHA-256 `acef14509ce44347d53a99b252cd92814797df1698b5a4365c9e0ac0724cc4ce`.
- Final exact merge CI `30213225754`, Pages `30213225369`, and production smoke `30213225753`: passed.
- Fresh production browser session at 390 px: zero Shiny output errors before and after loading SRER, no overflow, and all 19 audited in-app interaction targets at least 44 × 44 CSS px.
