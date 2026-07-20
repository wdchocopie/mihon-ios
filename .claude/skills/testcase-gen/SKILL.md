---
name: testcase-gen
description: >-
  Generate test cases, test scenarios, and a requirements traceability matrix (RTM) from a
  project's spec documents (Features + Business Logic). Use when new or changed specs need test
  coverage, or when a module needs more coverage — triggered by "/testcase-gen", "generate test
  cases", "write test cases from spec", "sinh test case", "viết test case từ spec". Optionally
  scaffolds baseline test data (--data). NOT for writing unit tests in code and NOT for executing
  tests (use the smoke/integration/regression/release-test skills to run them).
version: 1.0.0
---

# Generate test cases & scenarios from specs

From the project's Features + Business Logic specs, generate **atomic test cases**, wire them into
**test scenarios** (smoke / regression / integration / system), and update the **RTM**
(traceability matrix). Optionally scaffold baseline **test data**. This skill is generic and works
on any project.

## Step 0 — Identify the project

1. **Find the docs root** as in the spec-gen skill (`--docs` → a directory containing specs +
   `qa/` → ask the user). The project's own QA rules/templates (README, TESTGUIDE, `_TEMPLATE`…)
   **beat** this skill's defaults.
2. If no QA structure exists, scaffold the standard one:

```
<docs-root>/qa/
  test-data/            # baseline data (one file per entity) · bug-bait.md · opening-balances.md · _INDEX.md
  test-cases/[<app>/]<module>.md        # atomic test cases — the original traceability source
  test-scenarios/
    smoke/ regression/ integration/ system/   # runnable scenarios by kind
    _RTM/[<app>.md]                     # traceability: BL → Scenario (primary) + Feature → TC (secondary)
  releases/             # one folder per test run (written by the *-test skills)
```

Identifiers: `TC-<APP>-<MOD>-NNN` (test case) · `TS-<APP>-NNN` / `TS-SYS-NNN` (scenario) ·
`AUT-…` (automated case) · `BUG-…` (defect) · `GAP-NNN` (test-basis doubt).

## Default principles

- **Black-box**: a test case is executed purely by interacting with the system; no source reading
  needed to judge pass/fail.
- **Detailed enough to run immediately**: preconditions, input data, every step — the runner never
  has to infer anything.
- **Self-sufficient for pass/fail**: expected results state concrete numbers, behavior, or the
  "verbatim message" — no other document needed for comparison.
- **Traceability**: every TC has a Traces line pointing to the Feature IDs / BL Rules it checks,
  each ID written as one full token.
- **Minimum coverage**: every Feature ID ≥ 1 test case; every BL Rule/Validation ≥ 1 covering
  scenario.
- **The unit of execution is the scenario, never a loose TC** — a scenario is a chain of TCs (some
  contain just one); the end state of one step is the precondition of the next.

## Workflow

### 1. Read the sources tests derive from

- **Features**: "Main flows" (Fn), the Validation table, the state–action matrix, the permission
  matrix, empty & error states.
- **Business Logic**: rules `-Rn`, the **"Self-verification" `-Vn`** scenarios (nearly ready-made
  TCs), the **"Worked numeric example"** (reference results), the "Error messages & constraints"
  table (each row is one negative test), "Behavior-changing configuration" (config tests).
- **The project's Gap Log**: GAPs touching this module — regression-guard TCs carry the `GAP-NNN`
  in their Traces.
- Existing suites: follow their format, continue TC numbering, avoid duplicates.

### 2. Write atomic test cases

Follow the project's suite format; if none exists use the default frame:

```markdown
#### TC-<APP>-<MOD>-NNN — <short name>
- Priority: P0–P3 · Type: <one or more kinds> [· Auto: AUT-…]
- Traces: <Feature ID · BL Rule · GAP-… — each ID as one full token>
- Preconditions: <configuration + baseline data required>
- Test data: <concrete input data>
- Steps:
  1. <each interaction step>
- Expected results:
  - <concrete number / behavior / "verbatim message">
```

Coverage by **test kind**: beyond the happy path, cover **boundary** (values at the edges),
**negative** (invalid actions must be blocked with the right message), **calculation** (compare
against the BL numeric example), **validation**, **state** (per the state–action matrix),
**permission** (per role), **configuration** (each behavior-changing toggle on/off).

Risk-based priority: **P0** = vital/money/release-blocking · P1 = high · P2 = medium ·
P3 = low/cosmetic. Which areas are P0 follows from the business — wherever wrong numbers cause
real damage (usually pricing/payment/ledger data).

If the spec lacks a reference number, **never invent one** — open a type-B GAP and note it in
the TC.

### 3. Wire scenarios & the RTM

- **Smoke**: the application's vital flows collected into a short suite (~10 items, P0, 30–60
  minutes) under `test-scenarios/smoke/` — the gate at the start of every run.
- **Regression**: per-module suites + pinned risks under `test-scenarios/regression/`.
- **Integration**: when the module interacts with other modules of the same application, write
  `TS-<APP>-NNN` chains under `test-scenarios/integration/`.
- **System**: business flows crossing multiple applications/tiers become `TS-SYS-NNN` under
  `test-scenarios/system/` — the key check is **data consistency across applications and the
  service**.
- **RTM**: update the primary **BL → Scenario** table and the secondary **Feature → TC** table;
  two-way traceability must close — any BL without a covering scenario gets one added.
- Update the project's `_INDEX`/catalog files if present.

### 4. Test data (with `--data`, or when gaps are found)

Four layers by lifecycle:

| Layer | Where |
|---|---|
| **Baseline data** (catalogs, entities — built once, reused) | Entity files under `test-data/`; realistic names, never "test1"/"SP-A" |
| **Bug bait** ("nasty" values planted in the baseline: very odd numbers, stock 0, limits exactly at the boundary…) | Values live in the baseline; explained centrally in `bug-bait.md` |
| **Opening state** (balances, opening stock…) | `opening-balances.md` — created through the UI while running tests, never seeded |
| **Generated data** (transactions) | Lives in the Steps of TCs, never in test-data |

When extending the baseline, bump its version (e.g. `FND-vN`) in `test-data/_INDEX.md`.

### 5. Finish

- Check links (project script if available).
- Report: new TCs by kind/priority, scenarios wired, the module's Feature/BL coverage (which IDs
  remain uncovered), newly opened GAPs.
