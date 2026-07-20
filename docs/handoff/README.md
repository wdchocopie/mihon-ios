# Handoff

Per-session state snapshots. When a work session ends (context reset, day's
end, passing to another agent/person), write a handoff so the next session
resumes without re-deriving where things stand.

## Files

- `HANDOFF.md` — the **current** handoff. Always the latest state. Overwrite it
  each session; the last one is the one that matters.
- `YYYY-MM-DD-<slug>.md` — optional archived snapshots for big milestones worth
  keeping. Most sessions just overwrite `HANDOFF.md`.

Use `../templates/handoff.md`.

## What a handoff captures (that the encyclopedia doesn't)

Standing docs say what the system *is*; a handoff says what's *in flight*:

- What was just done, what's half-done, what's next.
- Landmines — things that bit you, dead ends, gotchas not yet in the docs.
- Exact commands / files to pick up from (`path:line`).
- Open questions blocking progress.

Rule: durable facts graduate out of the handoff into the encyclopedia
(`ANDROID_TO_IOS_PLAYBOOK.md`, `decisions/`). The handoff is scratch state,
not a second source of truth.
