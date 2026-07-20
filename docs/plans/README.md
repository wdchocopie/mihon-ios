# Implementation plans

Per-feature/module task-by-task build plans: `YYYY-MM-DD-<slug>.md`, from
`../templates/plan.md`. Paired 1:1 with a spec in `../specs/` (same slug).

A plan is the work order: tasks with files, checkbox steps, and an exact
verification per task. Any coding agent should be able to execute it without
re-deriving the design — the spec holds the why, the plan holds the how.

| Plan | Scope | Status |
|---|---|---|
| [2026-07-19-mihon-ios-port.md](2026-07-19-mihon-ios-port.md) | Master conversion roadmap: Mihon → native iOS. Waves, effort, risk register, gating ADRs. | proposed — blocked on ADR-0 |

The master plan is the parent of every future per-module plan. Per-module plans
(`YYYY-MM-DD-<slug>.md`) pair 1:1 with a spec and should cite which wave of the
master plan they belong to.
