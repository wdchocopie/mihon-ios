# Per-flow tester subagent briefing

Dispatch each flow as its own `general-purpose` subagent (NOT the built-in `tester` agent — that
one only sees `mcp__playwright__*` and can't use the other servers). Set the Agent call's `model`
to **that flow's chosen tier** (Phase 2 — haiku for simple/gating/nav/smoke flows, sonnet for
branching/judgment flows; don't blanket the strongest model across the wave). Launch all subagents
of a wave **in one message** so they run in parallel.

Fill the template below per flow. Each subagent owns exactly **one** Playwright server namespace.

```
You are driving a LIVE browser to QA-test a web app. Use ONLY the `mcp__<SERVER>__*` browser tools
(e.g. mcp__playwright3__*). Do NOT touch any other playwright namespace — other agents own those and
sharing a browser causes collisions.

FIRST: these tools are deferred. Load their schemas with ToolSearch:
  select:mcp__<SERVER>__browser_navigate,mcp__<SERVER>__browser_snapshot,mcp__<SERVER>__browser_click,mcp__<SERVER>__browser_type,mcp__<SERVER>__browser_take_screenshot,mcp__<SERVER>__browser_wait_for,mcp__<SERVER>__browser_console_messages,mcp__<SERVER>__browser_press_key
Then use those tools for everything.

APP: <BASE_URL>   (backend: <API_URL>, already running)
LOGIN: role <ROLE> — email `<EMAIL>` / password `<PASSWORD>`

FLOW: <FLOW NAME>
Steps (follow exactly; snapshot before acting so you target the right element):
  1. <step>
  2. <step>
  ...
Expected outcome / pass criteria: <what proves it works>
Edge cases to note: <...>

BUDGET (stay tight — don't over-probe): step through at most <N> representative items — one per
distinct type/state, NOT every item in a list. Try each control at most twice; the moment its
expected outcome is confirmed (or clearly fails), move on — don't keep poking a control that works.

PROVE SUCCESS BY DURABLE STATE, NOT BY TOASTS: success/failure is shown by a lasting change — the
queue advanced, a row appeared/disappeared, a status badge changed, the URL changed, the value
persisted after a refresh. Toasts vanish in a few seconds; do NOT spend turns trying to screenshot
one. If you happen to catch a toast, note it, but always assert on the durable state change.

While testing: after each meaningful step take a screenshot, and watch the browser console +
network (browser_console_messages) for errors. If an API call shows CORS / ERR_FAILED, record the
exact URL — it often means a backend 5xx, not a real CORS-config issue. A 403 on an admin-only
endpoint while testing a non-privileged role is usually CORRECT gating — record it as expected, not
as a bug.

If the flow is BLOCKED (missing data, element absent, error), capture evidence and STOP — report
the blocker; don't fake completion.

Leave the browser OPEN at the end (the orchestrator will close it).

REPORT BACK (your final message is the result — concise, structured):
- Steps completed / failed.
- Per-step observations (did each screen render? controls present/enabled?).
- Console + HTTP errors (quote them).
- VERDICT: ✅ pass / ⚠️ partial / 🚫 blocked — with a one-line justification.
```

## Orchestrator tips
- Give every subagent the **documented** flow from `TEST_MATRIX.md` — don't make them re-discover steps; that wastes tokens and invites drift.
- Keep one subagent per server per wave. Track which server each flow used so you can re-dispatch cleanly on retry.
- If a subagent comes back blocked on **data state** (e.g. "no records to act on") or a missing login, that's a real finding — but it usually means the Phase-0 account/data pre-flight was skipped. Verify accounts and data preconditions up front (Phase 0 §5) so agents don't discover them mid-session and waste a whole browser run.
- Give every flow a **model tier and a step budget** (Phase 3 §1). A narrow, budgeted flow on the right-sized model is cheaper and sharper than a broad one on the strongest model.
- Token rough cost: a live MCP flow runs ~40–80k tokens depending on step count and snapshots — and over-probing (chasing toasts, stepping every list item, retrying a working control) pushes it well past 100k. The budget + durable-state rules in the template exist to keep flows near the low end. Factor it into how finely you decompose.
