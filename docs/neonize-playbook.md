<!-- neonize-playbook-stub: v1 -->
# NEONize playbook: pointer for Mosquito Pulse

The NEON suite playbook has one home, read by Claude Code and Codex alike:
https://github.com/tgilbert14/NEON-Driver-Cascade/blob/master/docs/neonize-playbook.md
(side-by-side clone: `../NEON-Driver-Cascade/docs/neonize-playbook.md`). Read it before
suite work. Fold every suite rule, pattern or gotcha into that file, never into this one.
Anything here beyond this pointer and the app facts below is a stale fork: report it.

## This app

- Repo `NEON-Mosquito-Pulse` · watched branch `master` · product `DP1.10043.001`
- Rung specialist: `fauna`
- Refresh: `refresh-data.yml` fires Saturdays 13:17 UTC and its calendar gate runs the first-week Saturday; producer, validator and restricted publisher push the validated candidate to review branch `automation/mosquito-release-2026`. A person opens and merges the PR into `master`, and that merge is the deploy.
- Local authority files: `docs/SCIENCE-CONTRACT.md` (opportunity, zero, expansion and claim rules), `docs/BUILD-TEST-HANDOFF.md` (dated session ledger and next action), `DEPLOY.md` (release steps and production markers), `docs/EXPERT-REVIEW.md` (pre-release methods review), `docs/DRIVER-KNOWLEDGE-PACKAGE.md` (what the Driver may consume)

## App-specific rules

- Rebuild from immutable RELEASE-2026 in empty staging with all 47 sites; regenerate derived indexes and `manifest.json` only after the site candidate is promoted into the pinned validator worktree, and never hand-edit either.

## Owner-settled house rules (both tools)

- Default demo, startup and picker pre-selection site: **SRER** (then JORN, SJER, MOAB, ONAQ) unless this app documents a reason.
- Copy voice on covers, share cards and in-app copy: plain words a non-expert follows; say what NEON is; no em dashes; no sales pitch (price, access, ease); no hype adjectives; no sincerity labels ("honest", "real data"); never state what the reader can already see.
- No visible "illustration" badge on poster art; the art's status lives in alt text and the image provenance record.

Cold boot: also grep the fleet's `.claude/agents/LESSONS.md` in TG-Data-Apps (Codex: the
`dev-teams` mirror) for your role name: `grep -E '^- \[[0-9-]*\] [a-z0-9+-]*<role>[ +]'`.
