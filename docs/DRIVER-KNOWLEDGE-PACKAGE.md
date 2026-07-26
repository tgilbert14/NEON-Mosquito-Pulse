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
