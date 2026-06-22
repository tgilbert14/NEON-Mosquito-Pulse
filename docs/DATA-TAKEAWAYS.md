# Data takeaways — NEON Mosquitoes from CO2 traps (DP1.10043.001)

The per-app data audit (suite convention). What the product is, what it can honestly say, and the traps to avoid.

## The product

CO2 light traps run a dusk-to-dawn bout at fixed plots. Dry ice (CO2) mimics a breathing host; **host-seeking female mosquitoes** fly to it. The catch is sorted, a large catch is **subsampled and weighed**, and an expert identifies the subsample to species and sex.

Three tables, joined from the trap outward:

| Table | One row = | Key fields (the REAL DP1.10043.001 schema) |
|---|---|---|
| `mos_trapping` | one trap deployment (one trap-night) | `sampleID`, `plotID` (no `trapID` — one trap per plot), `setDate`, `collectDate`, **`trapHours`**, `nightOrDay`, `targetTaxaPresent`, `sampleCondition`, `decimalLatitude/Longitude` |
| `mos_sorting` | one sorted subsample | `subsampleID`, `sampleID`, **`proportionIdentified`** (the fraction identified — NOT weights), `sampleCondition` |
| `mos_expertTaxonomistIDProcessed` | one (subsample × species × sex) tally | `subsampleID`, `family`, `genus`, `scientificName`, `taxonRank`, `sex`, **`individualCount`**, `identificationQualifier` |

There are **no** `subsampleWeight`/`totalWeight`/`sampleType`/`trapID` columns in the live product — the bundler uses what is actually there. The expert-ID table is Culicidae-only, so all rows are target mosquitoes (`is_target` via `family`); bycatch is not carried.

**Effort keeps the zeros.** Zero-catch trap-nights (`targetTaxaPresent = "N"`) carry NA `sampleID`, so the effort frame is keyed on the trap-night identity (`plotID` + `collectDate`), NOT on `sampleID` — otherwise all the zero-catch nights collapse and the denominator is wrong. The pulse, hero index, and ubiquity all divide by this same deployment-level effort.

## The honest unit

```
estimatedTotalCount = individualCount / proportionIdentified   # scale the identified fraction to the whole trap
activity index       = Σ estimatedTotalCount / trap-nights      # trap-nights = Σ trapHours / 24, over ALL deployments
```

**Mosquitoes per trap-night** is a **within-site activity index, not a population.** It is the analogue of the bird app's "birds per count." Round only at display; never round the continuous expansion per-record before summing.

## What it can say / can't say

| ✅ Defensible | ❌ Over-reach |
|---|---|
| Within-site activity index (per trap-night) | Absolute population / density |
| Species richness (rarefied / Chao2) | Population sex ratio (the all-female catch is the trap's bias) |
| Seasonal **monsoon pulse** (the headline) | Disease risk / infection prevalence (separate NEON product) |
| Genus composition; **Culex** (WNV) share | "Biting rate" (host-seeking ≠ human biting) |
| Cross-site **direction** (space-for-time) | Cross-site **magnitude** ("Site A is buggier than B") |

## The traps to avoid

1. **Per-trap-hour vs per-trap-night.** Per-trap-hour numbers are tiny and unintuitive; the suite uses per-trap-night and states the conversion. Keep the precise hour denominator internally.
2. **Inner-joining away the zeros.** A `targetTaxaPresent = "N"` trap-night is real effort with zero catch. Drop it and the index biases upward.
3. **trapHours = NA/0 ≠ zero catch.** It is *no usable effort* — dropped from the denominator, never divided by.
4. **Female-heavy is the method, not biology.** Always frame the ~95% female catch as the CO2 trap selecting host-seekers.
5. **Day vs night bouts.** A NEON bout is one night interval plus the following day interval; the protocol intends BOTH, so the app counts both in the activity index and its denominator (it does not filter to night-only). The `daytime trap bout` QC flag is informational, surfacing day-heavy effort for the curious — not a correction.
6. **Desert "warmer = more" is non-monotone.** Warmth speeds larval development up to an optimum (~24–28 °C for Culex), then extreme heat + evaporation *suppresses* the pulse. State the ceiling; don't encode a monotone temperature prior in deserts.
7. **Annual per-site verdicts are underpowered.** Mosquito annual series are short and zero-inflated (worse than the n≥6 cascade floor). The within-season weekly pulse is testable where the annual link is not; cross-site claims must be **pooled** (one sign-vote per site), never per-site-verdicted.

## QC flags shipped (clickable, downloadable)

`trapHours missing/zero` (high) · `catch present but targetTaxaPresent=N` (high) · `large subsample expansion (low proportionIdentified)` (warn) · `compromised sampleCondition` (warn) · `uncertain identification` (info) · `daytime trap bout` (info).

## Sources

NEON DP1.10043.001 product page + User Guide; TOS Protocol & Procedure: Mosquito Sampling, NEON.DOC.014049; the `neonDivData` standardized-data design (Li et al. 2022, *Ecosphere* e4141); Reisen et al. on *Culex tarsalis* GDD / WNV ecology; Shocket et al. 2020 / Mordecai et al. 2019 (unimodal thermal response); Shaman & Day 2007, Chuang et al. 2011 (precip–emergence lags); Chao 1987 / Colwell et al. 2012 / Chao & Jost 2012 (richness estimation).
