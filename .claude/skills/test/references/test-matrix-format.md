# TEST_MATRIX.md format

`TEST_MATRIX.md` lives at the **project root**. It's the source of truth for what can be tested,
how, and with what settings. The `/test` skill reads it on every run and keeps it updated.

## Sections

### 1. Config (read by the skill)
A small key/value block the skill consults before running:

```markdown
## Config
- subagent_model: <unset until the user chooses — skill STOPS and asks if missing>
- base_url: http://localhost:5173
- api_url: http://localhost:8005/api/v1
- max_parallel_servers: auto
```

- **`subagent_model`** — which model the tester subagents use. If absent/blank, the skill must stop and ask, then write the answer here. A single value (e.g. `claude-haiku`) pins every flow to that model; the value **`mixed`** tells the skill to right-size per flow — `claude-haiku` for simple gating/nav/smoke/read-only flows, `claude-sonnet` for branching/judgment flows (see Phase 2). `mixed` is usually the most cost-effective choice; the `Flows` table may carry a per-flow tier note when it helps.
- **`base_url` / `api_url`** — where the running app and API live.
- **`max_parallel_servers`** — `auto` (default) uses every configured isolated server (**minimum 3, no maximum**); or set a number to cap how many run at once. Caps wave size.

### 2. Credentials / roles
The login accounts each flow uses (reference, not secrets you wouldn't commit — keep real secrets in env):

```markdown
## Roles
| Role | Email | Password |
|------|-------|----------|
| admin | admin@evo.com | Admin@123 |
| qa_reviewer | qa1@evo.com | Password@123 |
```

### 3. Flows (the matrix)
One row per testable flow. Each flow becomes one subagent.

```markdown
## Flows
| ID | Feature | Role | Steps (summary) | Pass criteria | Mode | Last result |
|----|---------|------|-----------------|---------------|------|-------------|
| F1 | … | … | … | … | mcp / script | ✅ 2026-06-20 |
```

- **Mode**: `mcp` (default — live agent run) or `script` (a recorded repeatable Playwright script; put its path in the Steps cell).
- **Last result**: updated after each run (✅/⚠️/🚫 + date) so coverage is visible at a glance.

### 3b. Cases (the exhaustive enumeration — Phase 1.5)
The full think-long-and-hard case list produced by `references/case-enumeration.md`, recorded so
coverage is visible and reproducible. Every case is kept here even when a run defers it; priority
governs run order, not inclusion. Flows in the matrix above are built by grouping these cases.

```markdown
## Cases
| ID | Feature | Who (role/auth) | Precondition / state | Action | Expected outcome | Priority | Flow |
|----|---------|-----------------|----------------------|--------|------------------|----------|------|
| C1 | … | author | book at draft | submit for review | moves to author_review, toast shown | P0 | F2 |
| C2 | … | author | zero books | open editorial list | real empty state, no crash | P1 | F2 |
```

- **Priority**: P0 (happy path + data-loss/security/blocking), P1 (common edge/error), P2 (polish/rare).
- **Flow**: which Flow row (F#) runs this case. Blank = enumerated but not yet assigned → a coverage gap to close.

### 4. Scripts (repeatable)
When a flow is converted to a standalone Playwright script, list it here with its path and run command, so future runs of that flow use the script (cheap) instead of a live agent.

```markdown
## Repeatable scripts
- F1 → `e2e/f1-login-smoke.spec.ts` — `npx playwright test e2e/f1-login-smoke.spec.ts`
```

## Keeping it honest
- Every flow the skill runs should exist here first (Phase 1 gate). If it's not documented, document it before testing.
- Don't mark coverage complete when a flow was blocked or inconclusive — record the real status.
