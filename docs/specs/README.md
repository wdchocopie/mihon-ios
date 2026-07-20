# Design specs

Per-feature/module design specs: `YYYY-MM-DD-<slug>-design.md`, from
`../templates/spec.md`.

Workflow for any module port or feature (agent-agnostic — any coding agent
follows this):

1. Read the corresponding Android source first — it is the behavioral spec.
2. Write the design spec here — iOS design + settled decisions.
3. Stress-test it (question every assumption) before building.
4. Write the paired plan in `../plans/YYYY-MM-DD-<slug>.md` (same slug).
5. Build against the plan, checking boxes.

Dated filenames, chronological, never renumbered. Spec + plan share a slug.

Load-bearing decisions made in a spec get promoted to `../decisions/` so they
live in the standing encyclopedia, not just the frozen trail.
