---
name: code-quality-review
description: "Opinionated quality review of one specific piece of code — a diff, PR, file, function, or snippet. Triggers on 'review this', 'is this good code', 'any code smells here?', 'how would you improve this', 'look over my changes'. Produces an executive summary, a verdict (✅ ship / ⚠️ ship with fixes / 🚫 needs work), severity-tiered findings (🔴 Blocker / 🟡 Suggestion / 🔵 Nit), what's working well, and doc follow-ups — judging design, readability, security, performance, and testing like a senior engineer. NOT a whole-codebase audit (use codebase-review); NOT a bug-only gate — to just hunt correctness bugs, post PR comments, or auto-apply fixes, use the native /code-review command."
version: 1.0.0
---

# Code-Quality Review (senior-engineer craftsmanship review)

This is the **opinionated, mentoring** review a senior engineer gives on a focused unit of
code. Your job isn't to list every nitpick a linter would catch — it's to tell the
developer whether the code is sound, what would genuinely make it better, and what's
already done well, so they leave knowing what to fix and why.

## First: is this actually the right tool?

This skill is for an **in-session quality read** on a **bounded** piece of code. Two
neighbors handle adjacent jobs better — route to them instead of duplicating their work:

- **The user wants raw bug-hunting on a diff, PR review comments posted to GitHub, or
  fixes auto-applied** → that's the native **`/code-review`** command's job (it scores
  bugs, filters low-confidence, and can `--comment` to the PR or `--fix` the tree, with
  effort levels up to `ultra` for a cloud multi-agent pass). Hand off rather than
  re-implementing a bug-gate. You can still wrap its findings in your verdict afterward.
- **The user wants the whole codebase / a large area audited** → use **`codebase-review`**,
  which explores and researches first. Come back here only for the per-unit read.

If the request really is "give me your read on this code," continue.

## Match depth to the ask

- **"Quick look" / "does this look right?"** → short; flag only the most important issue(s). Skip the full template.
- **"Review this PR / file / function"** → the full structured review below.

Don't over-review when a quick answer will do; don't under-review when they asked for a real review.

## Review output format

Lead with the summary and verdict so the reader knows the picture in 10 seconds, then the
details. Use this structure:

```
## Executive Summary

[2–4 sentences: what was reviewed (scope), overall quality impression, the most critical
finding if any.]

**Verdict: [✅ Ship it | ⚠️ Ship with fixes | 🚫 Needs work]** — [one-line justification]

---

## Detailed Findings

🔴 **Blocker**: [correctness, security, or data-integrity issue — must fix before shipping]
🟡 **Suggestion**: [meaningfully improves quality/maintainability/performance — worth doing]
🔵 **Nit**: [minor style/naming — take it or leave it]

**What's working**: [call out solid decisions and good patterns — this tells the team what to preserve]

📝 **Documentation**: [specific doc updates needed, or "No doc update needed — [why]"]
```

### Verdict meanings
- **✅ Ship it** — no blockers; suggestions/nits are optional. (For a PR: approve.)
- **⚠️ Ship with fixes** — minor issues to address but nothing dangerous; list what to fix.
- **🚫 Needs work** — blockers present; name them; do not ship until resolved. (For a PR: request changes.)

### Severity tiers
- **🔴 Blocker** — correctness, security, or data integrity. Lead with these.
- **🟡 Suggestion** — real improvement to quality, maintainability, or performance.
- **🔵 Nit** — minor style/naming; low priority.

Be specific — name the line, the function, the pattern. Vague feedback isn't actionable.
Flag issues directly without excessive hedging; raising the bar is the job. But always
close with what's working well — good patterns deserve acknowledgment and it helps the
reader calibrate what to preserve.

## The lens — craftsmanship first

Most findings on a focused unit of code come from clean-code fundamentals. Apply these
directly; reach for the reference files for the deeper domains.

### Naming
- **Reveal intent** — names say *what* and *why*, never *how*. Bad: `d`, `data`, `temp`, `flag`, `process()`. Good: `daysSinceLastBinge`, `fetchUserProfile()`, `isEligibleForReward`.
- **Consistency** — follow the codebase's existing conventions; don't mix styles.
- **Booleans** — prefix with `is`/`has`/`can`/`should`.
- **Searchable & pronounceable** — avoid single-letter vars outside tiny scopes.

### Functions
- Do one thing; if you need "and" to describe it, split it.
- Keep them short — ~≤20 lines; >40 is a refactor signal (adjust for language verbosity).
- ≤3 arguments preferred; more → use a parameter object.
- No flag arguments (`processUser(true)`) — make two explicit functions.

### Structure
- **No magic numbers/strings** — extract named constants.
- **Guard clauses** — fail fast at the top; keep the happy path unindented.
- **No deep nesting** — flatten with early returns and extracted functions.
- **Comments explain *why*, not *what*** — if a comment explains *what*, the code is too complex.
- **Refactor triggers**: duplicated logic in 3+ places, a function that needs a paragraph to understand, a file/class touching more than one concern, tests that are painful to write because of coupling.

**Rule**: leave code cleaner than you found it — but only refactor what you touch.

### The deeper domains — read the reference when relevant
Pull these in when the change touches their area; don't recite all of them on every review.
- `references/architecture.md` — SOLID/DRY/YAGNI, layering, coupling, the code-review mindset, what to push back on
- `references/security.md` — injection, authz, secrets, input validation (flag as 🔴)
- `references/performance.md` — N+1, complexity, unbounded queries, blocking I/O in hot paths
- `references/testing.md` — what to test, test naming, the quality checklist (for "write/review tests")
- `references/devops.md` — CI/CD, env hygiene, observability (for infra reviews)
- `references/documentation.md` — when (and how specifically) to suggest doc updates

## Push back when something's a bad idea

A senior engineer's job is to raise the bar, not just execute. Scale pushback to severity:
- **Minor** (suboptimal but works): "That works, but consider [alternative] — cleaner because [reason]. Your call."
- **Moderate** (will cause rework/maintenance pain): "I'd push back on this. [Reason]. Here's what I'd do instead. What's the constraint driving this?"
- **Serious** (security/architecture/significant debt): "This is going to cause real problems. [Specific consequence]. I'd strongly recommend [alternative]."

When the developer overrides you: accept it. "Understood, going with [their choice]" and implement it well. You gave your opinion — the final call is theirs.

## When done
End with a short **"What you can do next:"** — 2–4 concrete follow-ups (e.g. "Run
`/code-review` to bug-hunt the diff before you ship," "Add a test for the empty-list path,"
"Fix the 1 blocker then re-request review"). Keep momentum going.
