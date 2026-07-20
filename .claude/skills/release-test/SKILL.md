---
name: release-test
description: >-
  Orchestrate a full release test round end-to-end — write the test plan, update the test basis,
  run Smoke (blocking gate) then Regression, Integration, System, record results, and produce a
  Test Report with a quantified Go/No-Go recommendation. Use for every new build/release —
  triggered by "/release-test", "test this release", "run a release round", "kiểm thử release".
  Composes the smoke-test, regression-test, and integration-test skills; the final Go/No-Go
  decision belongs to the Product owner.
version: 1.0.0
---

# Run a full Release test round (end to end)

Orchestrate one round through three phases: **Prepare → Execute → Conclude**. Each round is one
folder `qa/releases/<YYYY-MM-DD>-<env>/` holding three files `test-plan.md` · `result.md` ·
`report.md`. Scenario-suite steps reuse the exact procedures of the `/smoke-test`,
`/regression-test`, and `/integration-test` skills. This skill is generic and works on any project.

## Phase 1 — Prepare

1. **Find the project's docs root** (as in the sibling skills); open the project's releases
   template if present. **Create the round folder** `qa/releases/<YYYY-MM-DD>-<env>/` with the
   three plan/result/report files (copied from the project template, or built from the frame at
   the end of this skill).
2. **Scope the change**: from `--note`/release notes/diff, list the affected Feature IDs · BL
   Rules (method in the `regression-test` skill, Step 1). Without release notes, ask the user or
   diff between the two build baselines yourself.
3. **Write `test-plan.md`**: round info (build, environment, scope); **quantified Go/No-Go
   targets** (100% of planned scenarios executed · P0 scenarios 100% passed · the rest ≥ the
   agreed threshold · 0 open Blocker/Critical); **strategy** — which test levels this round runs
   (Smoke mandatory; Regression scoped via the RTM; Integration/System per affected chains);
   **roadmap** listing every scenario.
4. **Update the test basis**: new/changed features not yet covered by spec/TC/scenario get covered
   first via `/spec-gen` and `/testcase-gen` (including test data and the RTM). **Gate:** the
   basis covers everything new before moving on.
5. **Entry gate**: confirm the build is deployed to the right scope, dev handover (URL, tenant,
   version), baseline data + preconditions ready. If any condition is missing, stop and ask the
   user — **never test against a blind environment**.

## Phase 2 — Execute (sequential, gated)

| Step | Scenario suite | Gate |
|---|---|---|
| 1 | **Smoke P0** per app in scope (as `/smoke-test`) | Failure **STOPS the whole round**: record the result, file BUGs, return to dev; after the fix, smoke must pass before continuing |
| 2 | **Regression on the change area** (picked via RTM + downstream dependencies + high-risk group, as `/regression-test`) | S0/S1 defects stop the round; the user decides |
| 3 | **Integration** on the affected chains (as `/integration-test`) | |
| 4 | **System** — journeys crossing multiple applications/tiers (for multi-app projects); key check: **data consistency across applications and the service** (receiver's data matches sender's numbers) | |
| 5 | **Deep passes by test kind** (boundary/negative/permission/configuration) focused on P0/P1 + TCs tagged with open GAPs | |

- Record Pass/Fail per scenario into `result.md` **right after each step**, with observed numbers;
  out-of-scenario findings go to the plan's discovery log.
- Defects get `BUG-…` (severity S0–S4); after a dev fix, **retest** and update the result;
  test-basis doubts open `GAP-NNN` in the Gap Log.

## Phase 3 — Conclude & assess

1. Aggregate quantitatively into `report.md`: scenarios run/passed/failed per test level, defects
   by severity (open/closed), coverage vs plan, each Go/No-Go target checked off.
2. Update **RTM** coverage if this round added TCs/scenarios.
3. **Go/No-Go recommendation** with residual risks (blocked TCs, open GAPs, unfixed defects) — the
   final decision belongs to Product/the project owner (sign-off in the report); the AI only
   recommends, with numbers behind it.
4. Add the round's row to the releases index; check links if docs were edited.
5. Report to the user: result summary, paths to the round's three files, the Go/No-Go
   recommendation, and what remains open.

## Three-file frame (when the project has no releases template)

- **`test-plan.md`** — §0 Round info (round ID, build, scope, release notes) · §1 Targets (the
  quantified Go/No-Go table) · §2 Strategy (which scenarios, in what order, when to stop, data &
  preconditions) · §3 Roadmap (gated steps, each with a scenario table with Result and Discovery
  columns) · §4 Discovery log (one row per finding: BUG / GAP / note).
- **`result.md`** — preparation-step results + Pass/Fail per scenario/TC with evidence and
  observed numbers + the defect list (BUG IDs, severity, lifecycle state).
- **`report.md`** — aggregated numbers · Go/No-Go targets checked · outstanding & accepted
  defects · residual risks · release recommendation · sign-off.
