# Data takeaways

The release bundle begins with `mos_trapping`, not positive catch rows.

| Layer | Grain | Role |
|---|---|---|
| `effort` | one physical day/night interval | identity, duration, validity, supported zero, apparatus/sample context |
| `obs` | eligible taxon × sex lot linked to an interval | whole-trap-scaled catch outcome |
| `held_identifications` | ineligible identification lot | audit trail for invalid proportion, join, count, or effort |
| `effort_week` | site × year × week | opportunity-complete 24-hour effort denominator |
| `traps` | site × plot | mapping and plot-level effort summary |

The key lesson is that “keep the zeros” is necessary but not sufficient. A valid zero, an unknown outcome, a pending/held catch, and missed effort are different scientific states.

Activity is `Σ eligible target count / Σ(valid trapHours / 24)`. Incidence and accumulation use the count of exact valid intervals, including supported zeros. Coarser Culicidae count toward total activity but never species richness.

See `docs/SCIENCE-CONTRACT.md` for complete claims and exclusions.
