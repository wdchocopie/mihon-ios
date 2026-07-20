# TEST_MATRIX

Source of truth for browser-driven feature testing via the `/test` skill. Document a flow here
before testing it. See the skill's `references/test-matrix-format.md` for field meanings.

## Config
- subagent_model:            <!-- claude-haiku / claude-sonnet to pin all flows, or `mixed` to right-size per flow (haiku=simple, sonnet=branching/judgment). LEAVE BLANK to force /test to ask. -->
- base_url: http://localhost:3000
- api_url: http://localhost:8000/api
- max_parallel_servers: auto    <!-- use all configured isolated servers (min 3, no max); or a number to cap concurrency -->

## Roles
| Role | Email | Password |
|------|-------|----------|
|  |  |  |

## Cases
<!-- The exhaustive Phase-1.5 enumeration (see references/case-enumeration.md). Keep every case;
     priority governs run order, not inclusion. Group cases into the Flows below. -->
| ID | Feature | Who (role/auth) | Precondition / state | Action | Expected outcome | Priority | Flow |
|----|---------|-----------------|----------------------|--------|------------------|----------|------|
| C1 |  |  |  |  |  | P0 | F1 |

## Flows
| ID | Feature | Role | Steps (summary) | Pass criteria | Mode | Last result |
|----|---------|------|-----------------|---------------|------|-------------|
| F1 |  |  |  |  | mcp |  |

## Repeatable scripts
<!-- F1 → path/to/spec — run command -->

## Known issues / data prerequisites
<!-- e.g. "Flow X needs a record at status Y before it can be exercised." -->
