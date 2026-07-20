# Documentation Map

All durable knowledge about this project — what it is, why it's built this
way, and how each piece was made. Any agent (or human) references this before
acting. Agent-agnostic: nothing here assumes a specific coding agent or tool.

## Two kinds of docs

- **Standing reference** — the encyclopedia. Always reflects current truth.
  `ANDROID_TO_IOS_PLAYBOOK.md`, `decisions/`.
- **Work trail** — per-feature, mostly frozen once shipped. `stories/`,
  `specs/`, `plans/`.
- **Scratch state** — `handoff/`: latest session state so the next session
  resumes without re-deriving. Not a source of truth; durable facts graduate
  into the encyclopedia.

## Files

- `ANDROID_TO_IOS_PLAYBOOK.md` — **the porting strategy: phases, Android→iOS
  tech mapping, extension-system problem, hazards, open decisions. Read
  before any porting work.**

## Folders

- `decisions/` — durable decisions and tradeoffs (ADRs). Append-only.
- `stories/` — feature packets. One per user-facing change / ported module.
- `specs/` — per-module design specs (`YYYY-MM-DD-<slug>-design.md`).
- `plans/` — per-module task-by-task build plans (same slug).
- `handoff/` — per-session state snapshots (`HANDOFF.md` = current).
- `templates/` — reusable formats for the above.

## Rules

- **One source of truth per fact.** Schema lives in one file; others link.
- **Decisions are append-only.** Wrong later → new ADR, mark old `Superseded`.
- **Every doc carries a Status.** `draft | accepted | superseded | done`.
- **Docs drive the build.** Spec → stress-test → plan → build against the plan.
- `AGENTS.md` (repo root) stays the short entry point; it points here.
