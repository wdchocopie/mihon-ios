---
name: codex-triage
description: "Triage automated PR review comments left by Codex (the GitHub bot, chatgpt-codex-connector). Triggers on 'check the codex review', 'what did codex say on the PR', 'triage the codex feedback', 'look at the PR review comments', 'any review comments on the PR?', 'is codex right about X?'. Fetches the comments via the gh CLI, investigates each flagged issue against the actual source — reading the file, tracing usages, checking intent and whether it's already fixed — instead of parroting the bot, then returns a prioritized report classifying each as Fix Now / Fix Later / Dismiss and offers to fix the real ones. Also aware of Cursor draft PRs. NOT for a fresh review of your own code (use code-quality-review); NOT Claude's own bug-gate (use the native /code-review)."
version: 1.0.0
---

# Codex Review Triage

When an automated reviewer (Codex) leaves comments on a PR, the job is **not** to blindly
accept or reject them — it's to investigate each one against the actual codebase and
deliver an honest, prioritized verdict. Codex catches real mechanical bugs (stale
references, type errors, missing cleanup) but also produces false positives from missing
context. Your value is the judgment layer on top.

## Step 1 — Find the PR and fetch Codex comments

Identify the relevant PR (the one the user names, or the most recent):

```bash
gh pr list --head dev --base main --state all --limit 5 --json number,title,state
```

Fetch the inline review comments, filtered to Codex:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  --jq '.[] | select(.user.login | contains("codex")) | {id: .id, path: .path, line: .line, body: .body, created_at: .created_at}'
```

Also check top-level reviews:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --jq '.[] | select(.user.login | contains("codex")) | {id: .id, body: .body, state: .state}'
```

Codex uses priority badges: **P0/P1** are likely real bugs; **P2** are style suggestions.
If there are no Codex comments, say so and stop.

## Step 2 — Investigate each comment against the actual code

This is the critical step — don't parrot the comment back. For each flagged issue:
1. **Read the actual source file** at the flagged line, with 20–30 lines of surrounding context.
2. **Trace the usage** — if Codex says something is unused/stale/wrong, verify: grep for the symbol, check if it's used elsewhere, re-exported, or referenced dynamically.
3. **Understand the intent** — read the commit message / PR description; what looks like a bug may be a deliberate choice.
4. **Check if it's already fixed** — the branch may have moved since Codex reviewed. Compare current code against what Codex flagged.

## Step 3 — Classify each issue

- **Fix Now** — real, affects correctness/security/UX, fix before next deploy (actual bugs, stale refs causing runtime errors, security issues, broken imports).
- **Fix Later** — valid but low-risk; specify *when* it makes sense (e.g. "next cleanup sprint", "when we touch the auth module").
- **Dismiss** — false positive, already handled, or Codex misunderstanding context. Explain briefly why (e.g. "used dynamically in another file", "intentional per project convention").

## Step 4 — Present the triage report

```
## Codex Review Triage — PR #[number]

**[X] comments reviewed** | [Y] Fix Now | [Z] Fix Later | [W] Dismissed

---

### Fix Now
🔴 **[file:line] — [brief description]**
Codex said: [summary]
Investigation: [what you found in the actual code]
Action: [specific fix needed]

### Fix Later
🟡 **[file:line] — [brief description]**
Codex said: [summary]
Investigation: [your analysis]
When: [when to address it]

### Dismissed
🟢 **[file:line] — [brief description]**
Codex said: [summary]
Why dismissed: [specific reasoning]

---

### Summary
[1–2 sentences: was Codex's review mostly on-target or mostly noise? Any pattern in what it caught or missed?]
```

## Step 5 — Offer to fix

After the report, ask: "Want me to fix the [Y] 'Fix Now' items?" If yes, implement the
fixes, then offer to ship them.

**Fix only what you were asked to fix.** When you implement the approved items, change
exactly those lines and nothing more. The working tree may already hold uncommitted edits
the user or another agent made — leave them alone. Don't revert, undo, or overwrite
unrelated changes, and don't "reset to a clean state" before fixing. If pre-existing
changes collide with a fix, point it out and ask rather than discarding them. (Dismissing
a Codex comment means *not making* its suggested change — it never means reverting code
that's already there.)

---

## Other external review tools

### Codex (GitHub bot)
`chatgpt-codex-connector[bot]` posts inline comments. **Validate before trusting** — it
catches real issues (e.g. stale `setShowAllSuppliers` calls) but also false-positives.
Valid P0/P1 → treat as a Blocker and fix; valid P2 → a Suggestion; invalid → dismiss with a reason.

### Cursor (draft PRs)
Cursor sometimes opens draft PRs after its own review pass. When you find an existing draft
PR from `dev` to `main`:
- **Mine it for context** — the description/comments may have useful observations.
- **Close it** — the `/ship` pipeline creates its own PR with a consistent format; stale Cursor PRs clutter the list:
  ```bash
  gh pr close <number> --comment "Superseded — review incorporated into Claude Code workflow"
  ```

These tools are complementary: Codex/Cursor catch mechanical bugs; your job is the
higher-level read — architecture, design, security, and whether the code solves the right
problem. For that fuller read on the PR's own code, hand off to `code-quality-review`.
