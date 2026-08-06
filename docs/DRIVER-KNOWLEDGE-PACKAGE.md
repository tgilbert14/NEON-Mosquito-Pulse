# Driver knowledge package · Mosquito Pulse

## Decision — two explicit axes

**Scientific-contract and suite-platform axis: ADOPT.** The suite should adopt
outcome-state reconciliation for every opportunity-complete sampling product:
positive, supported zero, unavailable/unknown, held, and ineligible are distinct
states before aggregation. It should also adopt the independently validated
producer/validator plus restricted, reviewer-authenticated publisher contract.

**Ecological Driver axis: CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE
CHANGE.** Whole-trap-scaled target catch per 24 trap-hours remains a within-site
activity index. The released support and calendar overlap do not by themselves
define an eligible Driver adapter, registered seasonal/thermal model, or ecological
vote. Do not infer mosquito population, biting rate, pathogen presence, infection,
transmission, exposure, disease risk, or a causal climate response.

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

### Driver synthesis diagnostic · 2026-08-04

- The reviewed release contributes 203 app-supported mosquito site-years.
- Exactly 200 of those site-years match the Driver calendar, across 46 Driver
  sites; 7 sites have at least 6 matched supported years.
- PUUM is the one released mosquito site outside the Driver site roster. Its
  mosquito bundle remains eligible in the app, while its climate-gradient overlay
  remains held.
- These are measured compatibility diagnostics, not an ingestion decision.
  Calendar support alone is not an eligible adapter or a registered model, so no
  ecological vote or Driver byte follows from the match count.

## Engineering learning

- Separate producer, validator, and restricted publisher jobs. Only the publisher writes, and it opens/updates a review PR.
- Exact site rosters are release contracts. Numeric minimum thresholds are not.
- A release receipt needs product, release, DOI, generation date, per-site row counts, and raw digest.
- Keep build-only download packages outside the deploy manifest.
- Static cover art should be local, checksum-locked, described by meaningful alt
  text, backed by durable provenance, and reused between Pages and the app. The
  depicted trap must match the protocol; the poster face needs no visible art
  badge or caption.
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

## Authority separation and current platform head · 2026-08-04

- Science/data/runtime authority remains
  `935420e1e1aa79dcc3cf54d03ef150f6f0332b8d`; its documentation/receipt authority
  remains `91b4c713ebbdc717128de584273b995ec49dd622`.
- Compact Pages authority remains
  `ec0f2ba4df71040d1760c23338da39233b92db96`; its cover receipt remains
  `6450f0197ac3ee535c0059b80a5e041b5dfe0b9a`.
- Current default/workflow head
  `c86d775b8870995018818a48199899ca5670fc53` is platform-only. It repairs the
  restricted refresh handoff and exact-review-byte checks; it changes no source,
  scientific helper, bundle, estimator, manifest, runtime, Pages presentation, or
  ecological disposition.
- Current-head validation `30819020636`, Pages `30819018628`, and production
  smoke `30819021005` passed. Full refresh workflow `30863101351` also passed.
- Therefore the top-level split remains deliberate: **ADOPT** the reusable
  opportunity/outcome-state and restricted-publisher contracts; keep the mosquito
  ecological signal **CONTEXT / HOLD DRIVER INGESTION / NO DRIVER BYTE CHANGE**.

## Living Poster flow correction · 2026-07-26

**NONE / NO DRIVER BYTE CHANGE** — Trimming the Pages cover to the approved Suite
Living Poster V1 flow changes presentation only. The public face now stops after
the hook, promise, one CTA, dominant artwork, and compact collapsed honesty footer;
the full effort, expansion, and CAN/CANNOT explanation remains in the app and
durable scientific documents. No source, opportunity, zero, estimator, bundle,
manifest, app runtime, Driver adapter, or ecological disposition changed.

Reusable suite rule: a cover can preserve the load-bearing zero/missing and claim
boundary in one collapsed disclosure without turning the first impression into a
methods page. Artwork-first mobile order, one Driver route, one CTA, descriptive
alt text, durable provenance, accurate scientific depiction, no visible art badge,
and 44 px primary/disclosure controls remain part of the shared frame.

### Published cover authority

- Pages presentation authority: PR #7, exact head
  `db732ebaa1173f92e5a36511401060b4224cdde7`, merged as
  `ec0f2ba4df71040d1760c23338da39233b92db96`.
- Exact PR-head CI `30218822559`, merged-master CI `30218905672`, Pages
  `30218905198`, and production smoke `30218905626`: PASS.
- Fresh live 1440/390/320 browser acceptance confirmed the compact poster flow,
  intrinsic 1200×800 local artwork, no overflow, and empty warning/error logs.
- The prior `935420e` runtime/science disposition remains authoritative for the
  Connect product; `ec0f2ba` supersedes only the earlier verbose Pages-cover
  presentation.

## Visible art-label refinement · 2026-08-05

**NONE / NO DRIVER BYTE CHANGE** — Pages and the in-app poster remove only their
visible illustration badges. Both retain descriptive alt text naming the
screenprint and accurate unlit CO₂ fan-trap components, while
`docs/ART-PROVENANCE.md` retains the generator, prompt, derivation, dimensions,
and exact hashes. Executable absence assertions prevent either label or a visible
caption from returning.

The opportunity/outcome-state and restricted-publisher contracts remain
**ADOPT**; the ecological signal remains **CONTEXT / HOLD DRIVER INGESTION / NO
DRIVER BYTE CHANGE**. No release source, bundle, effort, zero, expansion,
estimator, join, support, adapter, vote, or Driver artifact changes in this
presentation-only refinement.
