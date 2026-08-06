# Repository operating instructions

These instructions apply to the entire repository. User and platform instructions take precedence.

## Mandatory entry point

Before inspecting, changing, testing, rebuilding, publishing, or reporting on this repository, read `docs/BUILD-TEST-HANDOFF.md`, `docs/SCIENCE-CONTRACT.md`, and `docs/DRIVER-KNOWLEDGE-PACKAGE.md` completely. For suite work, also read the Driver repository's complete `docs/NEON-SUITE-LEARNING-LOOP.md`, `docs/NEON-SUITE-REVAMP-PLAN.md`, and `docs/neonize-playbook.md`.

Start and end every session with `git status --short --branch`. Preserve changes you did not create.

## Scientific contract

- Product: NEON Mosquitoes sampled from CO₂ traps `DP1.10043.001`, `RELEASE-2026`, DOI `10.48443/rmw1-me46`.
- One sampling opportunity is one physical daytime or nighttime trap interval. It is defined by `mos_trapping`, independent of catch and `sampleID`.
- A supported zero requires valid effort and `targetTaxaPresent = N`. Missed, unusable, pending, or held outcomes are unavailable, not zero.
- The activity index is whole-trap-scaled target catch per 24 trap-hours. It is trap encounter/activity, not population abundance, density, infection, transmission, exposure, or health risk.
- Species richness and incidence use species/subspecies records only and the exact effort key. Coarser Culicidae records remain in total activity and genus composition where appropriate.
- Invalid or conflicting `proportionIdentified`, duplicate keys, unmatched catches, and unusable effort fail closed or enter the held table. Never substitute 1×.
- Day and night intervals are both standard and stay distinct. Preserve the pre-2018 and 2018-present protocol eras.
- Weather relationships are descriptive/correlational and must retain support and missing-data boundaries.

## Build and release rules

1. Runtime boots entirely from committed bundles and local assets.
2. `manifest.json` is generated only in the pinned R 4.5.2/Jammy validator using the dated 2026-07-15 package snapshot.
3. A refresh builds all 47 release sites in empty staging, verifies the exact roster and science contract, and publishes a review PR. It never writes unchecked bytes to `master`.
4. Every custom Shiny message handler accepts exactly one payload argument.
5. A release needs green checks on the exact PR head and merge, exact manifest equality, Connect's `mosquito-pulse-v1` marker, and Pages' `mosquito-pulse-poster-v1` marker.
6. The Pages and app covers use the static Living Poster, local responsive art,
   descriptive alternative text, durable recorded provenance, and an accurate
   unlit CO₂ fan-trap depiction. Keep visible illustration badges and captions off
   the poster face.

## Durable closeout

Before editing a durable record, re-read its latest entry. Update `docs/BUILD-TEST-HANDOFF.md` with commands, expected/actual outcomes, exact revisions, failures, residual risks, and next action. Update `docs/DRIVER-KNOWLEDGE-PACKAGE.md` with evidence and an explicit `ADOPT`, `HOLD`, `CONTEXT`, `COMPLEMENT`, `REJECT`, or `NONE` decision. Then update the Driver register without changing its release artifacts.
