# Test-phase scope brief (what to hand the consolidated `/test` run)

The orchestrator does **not** spin up raw tester agents, and it does **not** test part-by-part as
builders land. Once the **whole build has finished** — every wave complete, every part returned —
the verification is a **single** `Skill(test)` run over the *entire feature* (SKILL.md Step 4).
This file is the **scope contract** you package and hand into that one `/test` invocation, so it
enumerates the assembled feature exhaustively (its own TEST_MATRIX + parallel fan-out) while staying
bounded to *your change* instead of ballooning into a full-app QA pass.

The same contract is what you'd hand the **fallback raw `tester` agent** in the one narrow case Step 4
allows it (a purely-UI feature with no API surface and no Playwright servers configured). Either way the
goal is the same: the verification is concrete and honest — it confirms the feature actually works end to
end, and when it doesn't, it hands the owning builder enough to fix it without re-investigating.

## What to put in the scope you hand `/test`

1. **The whole feature you just built — all parts, as one consolidated target.** List the parts that
   landed and the surface each exposes (routes/URLs, endpoints, functions), so `/test` enumerates the
   assembled feature — including the **cross-part flows** (a UI that calls an endpoint you built, a flow
   spanning modules) that per-part testing would have missed. Keep it scoped to *this feature*, not the
   whole app — `/test all` is the heavier whole-app pass.

2. **The acceptance criteria — per part.** The same checkable conditions you gave each builder; these are
   what PASS/FAIL is measured against, and `/test` should verify each explicitly. Tag which part each
   criterion belongs to so a failure maps back to an owner.

3. **The file-ownership map.** Which builder owns which files (from Step 2). This is what lets you route a
   `/test` failure (with its suspected `file:line`) straight back to the right builder in Step 5 without
   re-investigating who wrote what.

4. **How to run and reach it.** From your Step 0 grounding: the dev command/port and URL, the API base,
   any **auth/seed credentials** and how sessions work, and the type-check/lint/test commands. `/test`
   can't verify anything it can't start.

5. **What to exercise.** Happy path against each acceptance criterion, the obvious edge cases
   (missing/invalid input, empty states, boundaries), the **cross-part integration flows**, and a
   confirmation the feature runs without errors (console/network/server logs as relevant). `/test` will
   expand this into its full Phase-1.5 case list — you're seeding it, not constraining it.

6. **The boundaries.** State plainly: *read source and drive the live app/API to verify — but do NOT
   write or edit production code, and never revert or overwrite anyone's changes.* `/test` reports; the
   builders fix. This keeps the working tree clean and the loop honest.

7. **The return format — a per-flow verdict you can collapse per part.** Require, for each flow:
   - **PASS** — every acceptance criterion met; list what was checked and how.
   - **FAIL** — for each issue: a one-line description, **severity** (blocker / minor), **steps to
     reproduce**, observed vs. expected, and the **suspected `file:line`** so — via your ownership map —
     the owning builder can act immediately. Order issues by severity.

## Example scope to hand `/test`

> **Verify the whole "user settings" feature I just built (3 parts):**
> 1. `PATCH /api/users/me` endpoint (backend) — owned by backend-builder, files `src/api/users.ts`,
>    `src/services/users.ts`.
> 2. Settings form component (UI) — owned by frontend-builder, files `src/pages/Settings.tsx`.
> 3. Shared `UserSettings` type — owned by backend-builder, file `src/types/user.ts`.
>
> Acceptance criteria — endpoint: 200 + updated record on valid patch; 400 on invalid field; persists to
> DB; auth required. Form: renders current values, submits a patch, shows success/error; validation
> mirrors the API. Cross-part: editing in the form actually updates via the endpoint and survives refresh.
> Run it: `npm run dev` on port 3000; API base `http://localhost:3000/api`; seed user <creds>, cookie
> session. Exercise: valid + invalid patches (API track); render + submit + validation + refresh (UI
> track); the end-to-end edit flow (integration). `npm run typecheck` + `npm test` pass.
> Boundaries: read source and drive the live app/API; do NOT edit code or revert anything.
> Return: per-flow PASS/FAIL — for each FAIL: description, severity, repro, observed vs. expected,
> suspected file:line.

(Hand `/test` the whole feature in one go so its enumeration sees the cross-part seams — but keep it
to *this feature*, not the whole app, so the run stays bounded. Tag each flow's track — `ui`, `api`,
or both — so `/test` picks the right briefing template and only consumes a Playwright server when a
flow actually has a screen.)

## Notes for the orchestrator

- **One consolidated run, after the whole build lands** — not per part as it returns, and not raw
  `tester` agents you spin up yourself. Hand `/test` the scope above; it manages its own enumeration,
  parallel fan-out, and concurrency, so you don't track a tester pool.
- Route each FAIL straight back to the **builder that owns the implicated files** via `SendMessage`
  (Step 5), using your ownership map to pick the right one; when a failure spans two parts, send it to
  both with the seam called out. Then **re-run `/test` scoped to the failed flows** (not the whole
  matrix). Cap at two fix rounds, then escalate to the human.
- If `/test` reports it can't run the app (missing deps, build broken) — or can't run the UI track
  because no Playwright servers are configured for a UI-only feature — that's itself a finding: report it
  as a blocker rather than marking the feature untested-and-fine. (See SKILL.md Step 4 for the one narrow
  case where a single raw `tester` agent is an acceptable fallback.)
