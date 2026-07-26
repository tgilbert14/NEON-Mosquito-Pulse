# Mosquito Pulse scientific contract

## Product and release identity

- NEON product: **Mosquitoes sampled from CO₂ traps** (`DP1.10043.001`).
- Immutable source: **RELEASE-2026**, generated 2026-01-23.
- DOI: **10.48443/rmw1-me46**.
- Release coverage used here: 2014-01 through 2024-12, 47 terrestrial sites.
- Primary tables: `mos_trapping`, `mos_sorting`, `mos_expertTaxonomistIDProcessed`.

The source receipt records one row per site with release identity, table row counts, and the staged raw-package MD5. The release builder fails if any canonical site is absent or extra.

## Opportunity grain

A sampling opportunity is one physical CO₂-trap interval represented by a `mos_trapping` row. Day and night intervals remain distinct even when they share a plot and calendar date.

The stable key is:

1. NEON row `uid`, when present; otherwise
2. `eventID × plotID × setDate × collectDate × nightOrDay`.

`sampleID` links a non-empty collected sample to sorting and identification. It can be absent when no target mosquitoes were collected, so it cannot define or count opportunities.

An opportunity enters the activity denominator only when sampling occurred, `trapHours > 0`, and plot/date identity is usable. Its continuous contribution is `trapHours / 24`.

Protocol eras remain explicit:

- 2013–2017: two nighttime intervals plus the intervening daytime interval per bout.
- 2018–present: one nighttime interval plus the following daytime interval, approximately 24 hours total per plot/bout.

## Outcome and zero contract

Every trapping interval is retained with one outcome state:

- `positive_catch`: eligible target observations link to the interval.
- `zero_catch`: valid effort and `targetTaxaPresent = N`.
- `catch_unusable_or_pending`: target presence or held identification exists, but no eligible expanded observation is available.
- `outcome_unknown`: valid effort without enough evidence for positive or zero.
- `not_eligible`: the interval does not enter the denominator.

Only `zero_catch` is a zero. The other non-positive states are unavailable and cannot be silently imputed.

## Count expansion and taxonomic gates

NEON can identify a subsample of a large catch. Eligible whole-trap count is:

`individualCount × (1 / proportionIdentified)`

Eligibility requires one unambiguous sorting record per `subsampleID` and `0 < proportionIdentified ≤ 1`. Conflicting duplicate mappings fail. Missing, zero, negative, or greater-than-one proportions are held; they are never changed to 1×.

- Total activity and genus composition retain eligible target Culicidae at coarser ranks.
- Species richness, Chao2, rarefaction, accumulation, and the species board require accepted species/subspecies rank and reject `sp.` or slash-combined names.
- Incidence uses the effort key. Accumulation includes valid zero-catch opportunities.

## Measures and claims

### CAN

- Describe whole-trap-scaled catch per 24 trap-hours within a site.
- Show phenology across weeks with opportunity-complete denominators and real zeros.
- Compare species incidence/ubiquity against all valid sampled intervals.
- Describe day/night support, protocol era, sample condition, apparatus flags, and held records.
- Explore cross-site climate associations as descriptive, confounded space-for-time patterns.

### CANNOT

- Estimate mosquito population size, density, demographic abundance, or a population sex ratio.
- Infer pathogen presence, transmission, exposure, diagnosis, or human-health risk from `DP1.10043.001`.
- Treat a missing, missed, unusable, pending, or held outcome as zero.
- Treat coarser identifications as species richness.
- Claim rainfall or temperature caused an observed activity change.
- Rank sites as intrinsically “more mosquito-filled” without acknowledging lure response, effort, detection, habitat, and protocol context.

### HELD

- Identifications with invalid/conflicting subsample expansion.
- Catches without an eligible sorting or effort linkage.
- Intervals without usable duration or identity.
- PUUM climate-gradient placement until an equivalent pinned environmental overlay is available; its mosquito bundle remains eligible elsewhere.

## Trap illustration boundary

NEON documentation calls the equipment a CDC light-trap assembly, but the
sampling protocol removes the bulb and deploys it without light; CO₂ is the lure.
Both Living Posters therefore show a moonlit scene and an unlit fan trap. Both
surfaces explicitly identify the art as illustration rather than field
documentation or a data record.

## Primary references

- [RELEASE-2026 product](https://data.neonscience.org/data-products/DP1.10043.001/RELEASE-2026)
- [NEON product Quick Start Guide](https://data.neonscience.org/api/v0/documents/quick-start-guides/NEON.QSG.DP1.10043.001v2?fallback=html&inline=true)
- [TOS Mosquito Sampling Protocol, revision N](https://data.neonscience.org/documents/10179/1883155/NEON.DOC.014049vN/7692f2a2-051d-36ef-7419-a6966aa181fd?download=true&version=1.0)
- [NEON mosquito collection overview](https://www.neonscience.org/data-collection/mosquitoes)
- [User Guide, revision G](https://data.neonscience.org/documents/10179/2237401/NEON_mosquito_userGuide_vG/b4fb257f-ef66-9fb0-e802-d3c701d09832?download=true&version=1.0)
