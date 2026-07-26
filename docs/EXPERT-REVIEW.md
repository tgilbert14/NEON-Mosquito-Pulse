# Pre-release scientific and methods review

Date: 2026-07-26  
Scope: DP1.10043.001 measurement, joins, effort, zero catches, expansion, richness, environmental claims, and visual method fidelity.

## Findings resolved

1. **Opportunity identity:** replaced plot/date identity with NEON `uid` or the full event/plot/set/collect/day-night composite.
2. **Zero-catch evidence:** only valid intervals with `targetTaxaPresent = N` are zeros. Held, pending, unknown, and missed outcomes remain distinct.
3. **Duration:** activity uses continuous valid `trapHours / 24`, labeled “per 24 trap-hours,” while incidence counts physical intervals.
4. **Subsample expansion:** retained `1 / proportionIdentified`; invalid values are held and conflicting duplicate mappings fail.
5. **Taxonomic support:** species/subspecies gates richness and incidence; all eligible target Culicidae can contribute to total activity.
6. **Protocol eras:** the pre-2018 two-night-plus-day and 2018-present night-plus-day designs are preserved as metadata.
7. **Health claims:** Culex context is descriptive only. The app explicitly excludes infection, transmission, exposure, diagnosis, and risk claims.
8. **Illustration:** the art shows an unlit CO₂ fan trap. “Light trap” is the equipment class, not the deployed lure in this protocol.
9. **Release:** source is pinned to immutable RELEASE-2026 and the exact 47-site roster.

## Gates

- Synthetic fixture checks day/night key separation, supported zero handling, invalid expansion hold, coarse-ID total retention, species gate, effort conversion, and opportunity-complete accumulation.
- Full bundle verifier repeats those invariants across all release sites and reconciles metadata/index totals.
- Climate comparisons remain exploratory and omit PUUM until an equivalent environmental overlay is pinned.

Status: implementation accepted for release validation; production acceptance awaits exact-head CI, generated bundle receipt, deployment markers, and browser QA.
