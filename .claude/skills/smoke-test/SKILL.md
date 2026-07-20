---
name: smoke-test
description: >-
  Run the project's P0 Smoke Test suite as a blocking gate — the vital flows (login, core business
  transaction, data recorded correctly). Use at the start of every test round or to quickly check a
  build — triggered by "/smoke-test", "run smoke", "smoke test the build", "chạy smoke". On any
  failure it STOPS and reports back instead of testing deeper on a broken build. Runs documented
  smoke scenarios from the project's QA docs; NOT for exploratory testing and NOT a replacement for
  the full regression suite.
version: 1.0.0
---

# Run the Smoke Test (P0 — blocking gate)

Run the project's smoke scenario suite as a **gate**: if any item fails, **STOP** and hand the
result to dev — never continue with deeper suites on a broken build. This skill is generic and
works on any project.

## Prepare

1. **Find the test basis**: the project's docs root (as in the spec-gen/testcase-gen skills), then
   open the smoke suite under `qa/test-scenarios/smoke/` (or the project's equivalent). **If no
   smoke suite exists**, tell the user and suggest running `/testcase-gen` first — never improvise
   a checklist and run it.
2. **Confirm the environment**: URL/tenant/accounts/build, access method (VPN, devices…). Sources:
   the `--env` parameter, the project's CLAUDE.md/memory, dev handover; if missing, **ask the
   user — never guess**.
3. **Pick the execution medium per application type**:
   - Web: automated browser (Chrome/preview tools).
   - Service/API: direct HTTP calls, comparing returned/recorded data.
   - Mobile/desktop: the project's automated test suite (if any) + driving the running app.
4. **Confirm baseline data + preconditions** the smoke suite needs are present in the environment;
   if missing, build them per the project's test-data docs before running.

## Execute

- Run the smoke items **sequentially**; each item is black-box: act, observe, compare against the
  **reference result** written in the item (numbers, "verbatim messages").
- Record Pass/Fail per item **immediately after running it**, with evidence (observed numbers
  copied out verbatim, messages, screenshots when driving a browser).
- **Any failed item stops the whole suite** (unless the user asked to run everything to collect
  failures): grade severity S0 (paralyzing — blocks testing itself) → S4 (trivial), and describe
  reproduction well enough for dev to fix.

## Record results

- With `--release <folder>` (part of a release round): write into
  `qa/releases/<folder>/result.md` and update the smoke gate in the round's test plan.
- Standalone run: create `qa/releases/<YYYY-MM-DD>-<env>-smoke/` (using the project's releases
  template if present, minimally a `result.md`), and add a row to the releases index.
- Defects get `BUG-…` IDs in the result; if a documented reference result looks wrong/stale, open
  a `GAP-NNN` in the Gap Log — **never silently edit expected results**.

## Conclusion returned to the user

- **PASS (gate open):** n/n items passed — regression/integration/system may proceed.
- **FAIL (gate closed):** the failed items + severity + evidence; recommend returning the build to
  dev and stopping the round.
