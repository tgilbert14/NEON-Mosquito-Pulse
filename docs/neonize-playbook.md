# Mosquito Pulse operating playbook

The suite-wide playbook lives in NEON Driver Cascade. Repository-specific rules are:

1. Read `SCIENCE-CONTRACT.md` before changing a metric or label.
2. Start from the physical `mos_trapping` interval and reconcile its outcome state.
3. Keep duration (24-hour effort units) separate from incidence (count of intervals).
4. Rebuild from immutable RELEASE-2026 in empty staging; require all 47 sites.
5. Rebuild derived indexes and manifest only after the site candidate is promoted into the validator worktree.
6. Publish the exact validated bytes to a review PR, never directly to `master`.
7. Use the static, local Living Poster with descriptive alternative text, durable
   provenance, and an accurate unlit CO₂ fan-trap depiction; keep visible art
   badges and captions off the poster face.
8. Close only after exact-head and exact-merge CI, Pages/Connect semantic markers, browser QA, and Driver register update.
