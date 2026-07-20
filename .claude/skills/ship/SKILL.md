---
name: ship
description: "One command to branch, commit, push, and open a PR — with optional merge and deploy. Before committing it flags junk / test-data in the working tree (scratch screenshots, snapshot dumps, .DS_Store, tool scratch dirs, build output) that shouldn't be shipped and offers to exclude, gitignore, or delete it. When the diff carries a manual production step the auto-deploy won't run by itself — a migration/backfill script, a stored-enum rewrite, a seed, a new env var / VITE_* flag, or a scheduled task — it flags that in a '⚠️ Manual deploy steps' section of the PR body (and the chat summary) so nobody merges and deploys blind. Triggers on /ship, 'ship it', 'commit and push', 'send this up', 'open a PR', 'push my changes', 'push this up'. Default: reads the project's conventions from AGENTS.md and inspects GitHub branches first, then creates a NEW branch off the repo's secondary branch (develop/feature/staging — main/master is primary and protected), CHERRY-PICKS ONLY the edits this session made — at hunk granularity, not whole files: a session-touched file that also holds foreign/pre-existing hunks gets only its session hunks staged, and if the session's hunks can't be cleanly separated from other unmerged changes it STOPS and flags rather than shipping them — commits that, pushes it, and opens a PR into the secondary branch — autonomously. Other uncommitted changes and foreign hunks stay in the working tree untouched. After opening the PR it ALWAYS (automatically, no prompt) folds the shipped commit into your local secondary branch (develop/dev, or main/master if no develop/dev exists) and deletes the local feature branch, so local branches don't pile up — this runs whether or not the PR was merged. Before declaring success it VERIFIES the pushed commits actually reach the base — either already in the secondary branch or carried by an OPEN PR — and never leaves work ORPHANED on an already-merged/closed PR head (a push lands but never ships); if it finds orphaned commits it cuts a fresh branch + new PR and re-checks (Step 5.6). AGENTS.md shipping conventions ALWAYS override these defaults. If the user wants a different flow, adapt to it and offer to record it in AGENTS.md. '/ship no pr' commits and pushes the new branch but stops before opening the PR. '/ship this chat' / '/ship here' are explicit aliases for that session-only default. '/ship to <branch>' targets a specific base branch for the PR; '/ship to main' / '/ship merge to main' is a PRODUCTION PROMOTION — it opens (and, with merge, merges + deploys) a PR from the integration branch (develop/dev/staging/feature) INTO main/master, to push what's on the integration branch live. Whenever it resolves, is told, or decides a repo's branch/shipping convention, it records that in AGENTS.md/CLAUDE.md (if not already there) so future runs follow it without re-asking. '/ship from where I am' / 'from here' ships the current branch as-is instead of cutting a new one. '/ship merge' merges the PR into the secondary branch and runs the production deploy per AGENTS.md. '/ship review' runs a senior-engineer review on the shipped diff. '/ship all' / '/ship all changes' / '/ship everything' is the ONLY mode that sweeps the ENTIRE working tree (every change, not just session files) — it runs an ORCHESTRATED multi-agent ship: it first pushes every branch that has unpushed commits, then fans out as many read-only agents as the change warrants to thoroughly understand the whole working tree, synthesizes their findings into a revert-safe PR plan (how many PRs, how to split them, and a merge order chosen so that reverting the riskiest PR drags nothing important with it — weighing feature-break risk against how cleanly each slice separates), and fans out again — one lane per repo — to ship those PRs. See '## Orchestrated ship (`/ship all`)'. '/ship cleanup' (explicit only — bare 'clean up' / 'tidy' / 'dọn dẹp' route to the standalone `cleanup` skill, which does the worktree fan-out) ships NOTHING new — it tidies each local repo: fast-forwards local develop to the shipped remote state, deletes local feature branches that are already merged (safe `git branch -d` only), and FLAGS anything not yet shipped (uncommitted work, unmerged branches, unpushed commits) without ever deleting or discarding it. See '## Cleanup — tidy local branches'. Modes combine: '/ship here no pr'."
version: 6.2.0
---

# /ship — Branch, Commit, Push, PR, Deploy

You are a shipping pipeline. Your job is to take the changes made **in this session**, package them into a clean commit on a **new branch**, push that branch, and open a PR from it into the project's **secondary branch** — and optionally merge and deploy. (Sweeping the *entire* working tree instead is `/ship all`.)

**The default `/ship` runs autonomously — no approval prompts.** When the user types plain `/ship`, ship *this session's changes* end-to-end without stopping to ask "should I proceed?" The user already told you to ship; don't make them confirm again. The only things that pause the default flow are genuine safety issues: a possible secret in the diff (Step 1), obvious junk / test-data that shouldn't be committed (Step 1), a push that gets rejected, or a working-tree conflict that blocks the ship. Everything else just runs.

## Two principles that override everything below

These two rules sit above the default pipeline. Read them first, because they change what "default" means for any given repo.

1. **AGENTS.md is the source of truth.** Before touching git, you ALWAYS read the project's `AGENTS.md` (and inspect the repo's actual branches via GitHub). If AGENTS.md defines *any* shipping convention — branch naming, which branch is the integration target, whether to cut a new branch or push to an existing one, commit style, PR base, deploy steps — **that convention wins over this skill's defaults, every time.** This skill describes a sensible default flow; AGENTS.md describes *this project's* flow. When they disagree, follow AGENTS.md and say so in one line.

2. **The user can redefine the flow, and you should capture it.** If the user pushes back on how `/ship` behaves ("don't cut a new branch, just push to develop", "name branches `feat/<ticket>`", "PR into `staging` not `develop`", "we squash-merge here"), **adapt immediately** — do it their way for this run. Then **offer to persist it**: "Want me to record this in AGENTS.md so `/ship` does it automatically next time?" If they say yes, write it into AGENTS.md's shipping section (or create that section). This is how the skill learns a project's real conventions instead of fighting them.

## Branch model — primary vs. secondary

`/ship` assumes the two-tier branch setup most teams use. Internalize this before touching git:

- **Primary branch** — `main` or `master`. The protected production line. **Never commit, push, or PR-target it by default.** It is the most protected branch in the repo.
- **Secondary branch** — `develop`, `dev`, `development`, `staging`, or whatever the project uses for day-to-day integration. This is the **default PR target**. New work flows into it via PRs from short-lived branches.

So the default flow is: **cut a new branch off the secondary branch → commit → push the new branch → open a PR from it into the secondary branch.** Each `/ship` produces its own branch and its own PR (unless AGENTS.md or the user says otherwise).

This is a deliberate choice: short-lived branches keep the secondary branch reviewable (every change arrives as a PR) and keep `main`/`master` untouched. If a project prefers committing straight to `develop` instead, that's a perfectly good convention — but it must be stated in AGENTS.md or by the user; it is not the default.

### Identifying the two branches

Branch **names** are the signal — not GitHub's "default branch" setting. A repo can set `develop` as its GitHub default yet still treat `master` as its release line, so don't equate "default branch" with "primary branch."

- **Primary branch**: the branch named `main` or `master` (prefer `main` if both exist). Enumerate with `git branch -a` / `gh repo view` when unsure.
- **Secondary branch**, in priority order:
  1. The branch AGENTS.md names as the integration/target branch.
  2. The branch the user named — "ship to staging" → `staging`.
  3. An existing `develop` / `dev` / `development` / `staging` branch — **this is the default PR base for a plain `/ship`.**
  4. If no secondary branch exists at all (the repo has only `main`/`master`): fall back to PR-ing the new branch into the **primary** branch, and say so in one line. The new-branch step still happens — you just never had a secondary to target.

If AGENTS.md and the live branches disagree (e.g. AGENTS.md says `develop` but no such branch exists on the remote), trust the live repo and surface the mismatch to the user.

## Guardrail — ship changes, never discard them

Shipping means *committing* the changes that already exist — it never means *removing* them. Do not `git reset`, `git checkout -- <file>`, `git restore`, `git stash`, `git clean`, or otherwise discard, revert, or overwrite anything in the working tree, even changes you didn't make in this session. Uncommitted work may be the user's own edits or another agent's in-progress work, and it's not yours to throw away. Creating a new branch with `git checkout -b` carries uncommitted changes along without discarding anything; merge mode uses a plain merge (no destructive reset); a rejected push is never force-pushed. If something in the tree looks wrong, conflicts, or blocks the ship, surface it and ask — revert only when the user explicitly tells you to.

## Cherry-pick the session's own changes — never the ambient working tree

In every session-scoped mode (plain `/ship`, `/ship this chat` / `session` / `here`), what you ship is **only the edits this session actually made — at hunk granularity, not just file granularity.** A file you touched this session may *also* carry hunks you didn't make: a teammate's uncommitted WIP, another agent's in-progress edit, or changes that were already dirty before this session started. Staging that whole file with `git add <file>` would ship those foreign hunks too — silently dragging **unmerged, unrelated work** into your commit. That is exactly what this rule forbids. The scope is *your* diff, never the ambient tree.

- **Reconstruct what the session changed.** From your own Edit / Write / Bash tool history this conversation, build the set of hunks *you* produced, per file. That set — and nothing else — is the ship scope.
- **Whole file is session-made → stage the file.** If a file's *entire* working diff corresponds to edits you made this session (a file you created this session always qualifies), `git add <file>` is already exact — ship it whole.
- **Mixed file → cherry-pick only your hunks.** If a session file also holds hunks you did *not* make, stage only the session hunks and leave the foreign ones in the working tree, uncommitted and untouched (mechanics in Step 3).
- **Inseparable → flag and STOP.** If your hunks and the foreign hunks overlap or interleave so they can't be split into clean, independently-appliable patch hunks — i.e. you cannot commit your change without also committing someone else's unmerged work — **do not ship.** Stop, name the file(s) and the colliding regions, state that a clean cherry-pick is impossible without pulling in other unmerged changes, and hand it back to the user. Never guess a split, never `git add` the whole file "to get unstuck," never `stash` / `reset` / `checkout --` the foreign hunks out of the way (guardrail above).

This is session-scoped only. **`/ship all` is the deliberate exception** — it sweeps the whole tree by design (and even there never splits one file's hunks across PRs). Everywhere else, the ship is a precise cherry-pick of the session's work, or it stops.

## Arguments

- **No arguments (default)**: Ship ONLY the files touched during **this session** — not the whole working tree — **autonomously, with no approval prompts**. Other uncommitted changes stay in the working tree untouched (Step 7 offers to ship them separately; `/ship all` sweeps the entire tree). Read AGENTS.md and inspect branches, cut a new branch off the secondary branch, auto-generate the commit message, commit, push the new branch, open a PR into the secondary branch, and stop there (do **not** merge the PR). Then **automatically fold the shipped commit into your local secondary branch and delete the local feature branch** (Step 5.5) — no prompt, and regardless of whether the PR was merged — so branches don't pile up. Only pause for a suspected secret, flagged junk / test-data, a rejected push, or a blocking conflict. **Exception — auto-continue:** if you're already on a non-primary/non-secondary branch that has an open PR, the default updates that branch/PR instead of cutting a new one (see Step 1.5), so re-running `/ship` after tweaking shipped work lands on the same PR.
- **`to <branch>`**: PR into the named branch instead of the auto-resolved secondary branch — "ship to staging" bases the PR on `staging`. The new branch is still cut and pushed; only the PR base changes. The named branch must already exist. **Special case — `to main` / `to master` (the primary branch) is a production promotion, NOT a feature ship:** it opens a PR from the *secondary/integration* branch into the primary (`develop → main`) so what's already on the integration branch goes live; `merge to main` also merges and runs the production deploy. See "## Promote to production (`/ship to main`)".
- **`from where I am` / `from here` / `from this branch`**: Skip cutting a new branch — ship the branch you're **currently on** as the PR head: commit, push it, and PR it into the secondary branch as-is. This is the escape hatch for continuing work on an existing branch instead of spawning a fresh one. (No effect if you're on the primary branch — never ship `main`/`master` as a head; fall back to cutting a new branch.)
- **`this chat` / `this session` / `here`**: Explicit aliases for the **default** — ship ONLY the files touched during this Claude Code session, ignoring other uncommitted changes. Same behavior as a plain `/ship`; the words just make the scope explicit. Examples: `/ship this chat`, `/ship this session`, `/ship here`.
- **`no pr` / `no-pr` / `just push` / `push only` (stop before the PR)**: Run the pipeline up through the push — cut the new branch, commit, push it — then **stop**. Do **not** open a PR. Use this when the work should land on a branch but isn't ready for review yet. Examples: `/ship no pr`, `/ship just push`, `/ship here no pr`, `/ship this chat no pr "WIP auth refactor"`. `no pr` is incompatible with `merge` (you can't merge a PR you didn't open) — if combined, ship without the PR and tell the user merge was skipped.
- **`merge` / `and merge`**: Ship as usual, ensure the PR exists, then immediately merge it into the secondary branch and run the project's production deployment pipeline (read from AGENTS.md). Examples: `/ship merge`, `/ship and merge`. Combines: `/ship here merge`, `/ship this chat merge "Fix the auth bug"`. Add **`cleanup`** to chain the standalone `cleanup` skill once the merge + deploy finish — `/ship merge cleanup` (see the `cleanup` suffix below and Step 9).
- **`all` / `all changes` / `everything`**: Ship the **entire working tree** — every staged, unstaged, and untracked change, not just this session's files. This is the only mode that sweeps beyond the session. Don't cram it all into one commit — run the **Orchestrated ship** (fan out to understand → synthesize a revert-safe PR plan → fan out to ship). Preamble first: in each repo, push any branches that already have unpushed *committed* work — enumerate with `git log --branches --not --remotes --oneline` and per-branch `git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads`, then `git push origin <branch>` (add `-u` if no upstream; never force-push; a branch with an open PR just gets updated). **Never push the primary branch** (`main`/`master`) even if it has unpushed commits — list them and ask. Then hand the *working tree* to the Orchestrated-ship section below. Combines with other flags: `all no pr` runs the plan but stops each PR before opening it; `all merge` merges each PR in dependency order (foundation first).
- **`review` / `and review`**: After shipping (branch + commit + push + PR), run a code review on the shipped diff using the senior-engineer skill. Examples: `/ship and review`, `/ship review`. Combines: `/ship here review`, `/ship merge review`.
- **Optional message override**: `/ship "Fix the auth bug"` uses their message as the commit summary line. Still auto-generate the PR body. Combines with other modes.
- **`cleanup` (explicit `/ship cleanup` only)**: Ship nothing new — **tidy the local repo(s)** so branches stop piling up. **Only the explicit `/ship cleanup` triggers this mode; bare `clean up` / `tidy` / `tidy branches` / `dọn dẹp` route to the standalone `cleanup` skill (worktree fan-out that commits/pushes/merges pending work first).** Fast-forward local `develop` to the shipped remote state, delete local feature branches that are already merged, and **flag anything not yet shipped** (uncommitted changes, unmerged branches, unpushed commits) — never deleting or discarding it. Safe by construction: only `git branch -d` (which refuses unmerged branches), fast-forward-only ref updates, no force, no `reset`/`stash`/`clean`. Runs per repo in a multi-repo workspace. See "## Cleanup — tidy local branches (`/ship cleanup`)". Standalone — doesn't combine with commit/push/PR modes.
  **The one exception — `cleanup` as a suffix on a real ship (`merge cleanup`):** when `cleanup` is appended to a shipping flow rather than run alone — canonically **`/ship merge cleanup`** — it does **not** mean the lightweight tidy above. It means: run the full ship (merge + deploy), then **hand off to the standalone `cleanup` skill** — `Skill(cleanup)` — as the final step (Step 9). That skill does the worktree-aware fan-out (commits/pushes/merges any pending work, then prunes), which is the right close after a merge lands. So: **`/ship cleanup` alone → ship-scoped local tidy mode; any ship flow + `cleanup` (e.g. `merge cleanup`) → chain `Skill(cleanup)` at the end.**

## Orchestrated ship (`/ship all`)

This is what `/ship all` / `/ship everything` runs when the working tree holds a big, mixed pile of changes. Instead of one giant commit, you **fan out to understand the changes, synthesize them into a revert-safe set of PRs, then fan out to ship those PRs.** The three normal modes (`no pr`, `merge`, `review`) still apply — they just apply to *each* planned PR.

The whole point is that a plain `/ship` here would bury unrelated work in one commit that can't be reviewed or reverted cleanly. `/ship all` produces several small, coherent PRs whose merge order is chosen so a later revert never orphans an earlier change.

**Right-size before fanning out (laziness gate).** If the working tree is small — roughly ≤ 5 files with one obvious concern — the fan-out is busywork. Skip all three phases, say so in one line ("Small, single-concern change — shipping as one PR"), and run the normal pipeline once — but staging the **whole tree** (`git add -A`), since `/ship all` still means all changes, not just this session's. The orchestration is for genuinely large or mixed trees; don't spawn a swarm for a three-file diff.

### Phase 1 — Understand (fan out, read-only)

1. **Inventory per repo.** This workspace has independent repos (`evo-books-studio-be`, `evo-books-studio-web`) — treat each separately; **a PR never spans two repos.** For each repo with changes, run `git status`, `git diff --stat`, and list untracked files to gauge scale and the rough concern-boundaries.
2. **Fan out.** Invoke `deep-exploration` (or dispatch `Explore` agents directly) — one read-only agent per **slice of the diff**, cut by feature / module / concern, scaling the agent count to the size of the change (more change → more agents; the floor is worth it only past the laziness gate). Each agent's brief points at its slice of files and asks it to report, for that slice:
   - **What changed and why** — the intent (feature, fix, refactor, config, docs).
   - **Which feature/domain** it belongs to (so like changes cluster).
   - **Files touched** (exact paths), and whether any are **shared** with other slices.
   - **Dependencies** — does this code import/require another slice's change to work?
   - **Break-risk** — how likely this needs reverting later. Treat backend **schema** changes, anything under `app/services/` (business logic), and stored-enum/status changes as **high risk** (they're also the AGENTS.md-gated areas). Isolated UI/docs/config = low.
   - **Test status** — is it covered, and does it stand alone?
3. **Capture findings into a context pack** at `.claude/plans/ship-all-<slug>.md` (the AGENTS.md context-pack convention) so Phase 3's ship agents read one distilled file instead of re-deriving the diff.

### Phase 2 — Synthesize the PR plan

Combine the findings yourself into a concrete plan. For each candidate PR decide its **file list, purpose, break-risk (H/M/L), cleave cost** (how hard it is to separate from the others — high when it shares files with another candidate), and **dependencies**.

**Deciding the PR count** — two forces pull against each other:
- **Split** independent, higher-risk features into their own PRs — a risky feature alone in a PR is a clean, surgical revert.
- **Merge** candidates that can't be cleanly cleaved (high cleave cost / shared files) into one PR. **Never split a single file's hunks across PRs** unless the user asks — a half-committed file is a broken build. If two features both need one shared file, that file goes into the **earliest** PR they both depend on.

**Deciding the merge order (revert-safety is the goal the user cares about most):**
- **Foundation / shared / low-risk changes first.** Anything other PRs depend on (shared types, utils, schema, config) merges early and is kept as low-risk as possible, because everything sits on top of it.
- **Dependencies always merge before their dependents.** A dependent PR stacks off its dependency's branch (base the PR on that branch), not off `develop`, until the dependency merges.
- **High-risk, independent features last (leaf PRs).** The riskiest, most-likely-to-be-reverted work goes at the tips, each isolated, so reverting it drags nothing important with it.
- **The invariant:** no early PR may depend on a later one. Dependencies point *backward* in merge order — that is exactly what makes reverting a late PR safe.

Output the plan as a table and proceed autonomously (it's `/ship all` — no approval prompt), but show it in the final summary:

```
| # | Repo | PR (ship/<slug>)      | Files | Risk | Cleave | Depends on | Merge order |
|---|------|-----------------------|-------|------|--------|------------|-------------|
| 1 | be   | ship/shared-types     | ...   | L    | high   | —          | 1 (first)   |
| 2 | be   | ship/import-dedup     | ...   | M    | low    | #1         | 2           |
| 3 | web  | ship/review-modal     | ...   | H    | low    | —          | 3 (leaf)    |
```

### Phase 3 — Ship (fan out)

- **Fan out one lane per repo, in parallel.** The repos are independent git trees, so `be` and `web` ship concurrently — dispatch one ship lane per repo in a single message.
- **Within a repo, ship the PRs in dependency-wave order** (foundation waves before leaf waves), each PR running the **normal per-PR pipeline (Steps 1.5–5.5)**: cut `ship/<slug>` off `origin/develop` (or off its dependency's branch for a stacked PR — carrying uncommitted changes along, never discarding), `git add` **only that PR's paths**, commit (Vietnamese, Conventional-Commits per AGENTS.md), push, open the PR into `develop`, and then **auto-fold the shipped commit into local `develop` and delete the feature branch (Step 5.5) — no prompt, whether or not the PR merged.** Because the fold runs in dependency-wave order (foundation first), each foundation PR's commit is already on local `develop` before its dependents fold on top. Flags flow through: `all no pr` stops each at the push (and skips the fold, per Step 5.5); `all merge` merges each in order (foundation first, and only once its checks are green).
- **One index per working tree ⇒ subset-commits serialize** within a repo (this is the same "no two writers on one file" rule as `parallel-execution`, applied to the git index). The genuine parallel wins here are **across repos** and the whole of **Phase 1**. To parallelize *independent same-repo* PRs on top of that, hand each same-wave PR to a **worktree agent** (`isolation: "worktree"`) with its file-subset patch + branch name + Vietnamese commit/PR text from the context pack — but only bother when a repo has many disjoint PRs; the sequential subset-commit loop is already seconds-per-PR.
- **Git-safety is absolute** (AGENTS.md overrides everything): each lane/agent only ever `git add`s its own paths and **never** runs `reset` / `checkout --` / `restore` / `stash` / `clean` / force-push, even to resolve a conflict. On a blocking conflict, stop and surface it.
- **Flag manual production steps** per AGENTS.md on the PR that needs them — schema migrations/backfills, stored-enum rewrites, seeds, new Coolify env vars / `VITE_*` flags, scheduled tasks. If a PR needs none, say so.

### Final summary

End with a per-repo, per-PR table showing branch, PR URL, merge order, and a one-line **revert-safety rationale** ("PR #3 is the highest-risk feature and merges last as an isolated leaf — reverting it touches nothing else"). Note anything skipped and any manual prod steps.

## Promote to production (`/ship to main`)

When the `to <branch>` target is the **primary** branch (`main`/`master`), `/ship` flips from "feature ship" to **production promotion**. Instead of cutting a feature branch and PR-ing it *into* the primary, you open a PR whose **head is the secondary/integration branch** (`develop`/`dev`/`staging`/`feature`) and whose **base is the primary branch** — promoting everything already integrated on that branch to production. `/ship merge to main` also merges it and runs the production deploy (Step 6B). This is the normal "update production" step: work lands on `develop` via ordinary ships, then a promotion PR moves `develop → main`.

**Flow:**
1. Resolve the two branches with the Step 1.5 rules. **Head = the resolved secondary/integration branch; base = the primary branch.** Do NOT cut a new `ship/<slug>` branch — the head is the integration branch itself.
2. Make sure the integration branch is pushed and current: `git fetch origin`; if the local integration branch is ahead of its remote, push it first (never force-push).
3. Open the PR with a **release-style body** — what's shipping since the last promotion: `git log <primary>..<secondary> --oneline` and `--stat`. Title/body in the language AGENTS.md requires (Tiếng Việt here). **This PR goes live** — so the `## ⚠️ Manual deploy steps` flag matters most here: run the "### Detecting manual production steps" scan over the whole `<primary>..<secondary>` range (migrations, backfills, stored-enum rewrites, seeds, new env vars, scheduled tasks) and list every action, since a promotion aggregates many feature ships and any one of them may carry a migration.
4. **`merge` variant** (`/ship merge to main`): merge the PR into the primary, then run the Step 6B production-deploy playbook. Use the project's merge strategy from AGENTS.md.
5. **Dirty working tree ⇒ not part of the promotion.** Uncommitted changes sit *below* the integration branch, so a promotion won't include them. If the tree is dirty, say so and offer to ship them to the secondary branch first (normal flow) and then promote.

**No secondary/integration branch exists** (the repo has only `main`/`master`, or nothing matching `develop`/`dev`/`staging`/`feature`): don't guess — ask which the user means:

1. **Ship the current changes straight to `main`** — this repo has no integration tier.
2. **Create a secondary branch** (e.g. `develop`) and adopt the normal two-tier flow (work → `develop` → promote to `main`).
3. **Promote the current branch → `main`** — if they're on a feature branch that should go live as-is.

If they confirm they **ship directly to `main`**, do it this run **and record that convention** in the repo's `AGENTS.md`/`CLAUDE.md` (see "When the user wants a different flow" → convention-recording) so future `/ship` targets `main` directly without re-asking. (Some repos already document this — e.g. `nxbgd-sbt-digital`'s AGENTS.md states every ship goes straight to `main`; when it's already there, just follow it.)

## Cleanup — tidy local branches (`/ship cleanup`)

**Distinct from the standalone `cleanup` skill** (worktree fan-out that commits/pushes/merges pending work before deleting anything): `/ship cleanup` is the lighter, ship-scoped local-branch tidy, and it fires **only** on the explicit `/ship cleanup` — bare `clean up` / `tidy` / `dọn dẹp` route to the `cleanup` skill.

After a run of ships, local repos accumulate feature branches whose PRs already merged, while local `develop` lags the remote. `/ship cleanup` brings local `develop` up to the **shipped** state and prunes the branches that are **safely merged** — **without shipping anything new and without ever discarding uncommitted work.** Anything not yet shipped is surfaced, never deleted. It commits nothing, pushes nothing, opens no PR.

Run this **per repo** (each independent repo the workspace defines — here `evo-books-studio-be` and `evo-books-studio-web`; skip the gitignored workspace-root tooling repo). For each repo:

### 1. Read state (read-only)

```bash
git -C <repo> status --short         # uncommitted work — flag later, never touch
git -C <repo> fetch --prune origin   # refresh remote-tracking refs; drop stale ones
git -C <repo> branch --show-current
```

Resolve the **secondary** branch from AGENTS.md (`develop`) and the **primary** (`master`). **Never delete or modify `master`.**

### 2. Fast-forward local `develop` to the shipped remote state

The shipped changes already live on `origin/<secondary>` (merged PRs). Bring local `<secondary>` up to them — **fast-forward only, never a rewrite:**

- **Not on `<secondary>`:** `git -C <repo> fetch origin <secondary>:<secondary>` — updates the local ref by fast-forward *without a checkout*, so the working tree is never touched. Fails harmlessly if local `<secondary>` has diverged.
- **On `<secondary>`:** `git -C <repo> merge --ff-only origin/<secondary>`.

If the fast-forward is **refused** (local `<secondary>` has its own commits, or a dirty tree would be overwritten), **stop and flag it** — do NOT `reset` / `pull` / force. Local `develop` carrying unpushed commits is itself "not yet shipped" (report it in Step 4).

### 3. Delete local feature branches that are already merged

```bash
git -C <repo> branch --merged <secondary>
```

Everything this lists — except `<secondary>`, `master`, and the branch you're currently **on** — is an ancestor of `develop`, i.e. safely merged. Delete each with the **safe** delete:

```bash
git -C <repo> branch -d <merged-branch>
```

- **Only `-d`, never `-D`.** `-d` refuses to delete a branch that isn't merged — that refusal *is* the safety net. If `-d` ever errors, the branch is not actually merged: leave it and flag it, don't escalate to `-D`.
- **You can't delete the branch you're on.** If the current branch is itself merged and you want it gone, switch to `<secondary>` first **only if the working tree is clean** (`git checkout <secondary>`); if the tree is dirty, leave the branch and flag it — never `stash`/`clean` to force the switch.
- **Squash-merge repos** (check AGENTS.md's merge strategy): `--merged` misses squash-merged branches because their commits aren't ancestors of `develop`. Only there, cross-check `gh pr list --state merged --json headRefName,number` and delete a local branch **only** once gh confirms its PR merged. This workspace merges with merge-commits, so `--merged` + `-d` is sufficient — don't reach for the gh path here.

### 4. Flag everything NOT yet shipped (report, never delete)

- **Uncommitted work** — the staged/unstaged/untracked files from Step 1. They stay in the tree, untouched.
- **Unmerged local branches** — `git -C <repo> branch --no-merged <secondary>`. Each has commits not in `develop`. For each, say which it is: **shipped-but-open** (has an open PR — `gh pr list --head <branch> --state open`) or **not shipped at all** (no PR). Leave both in place.
- **Unpushed commits** — `git -C <repo> for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads` (any branch showing `[ahead N]`).

### 5. Summary

Per repo, report: local `develop` result (synced to `<sha>` / already current / **ff refused — flagged**), the branches deleted, and a **"Not yet shipped"** block listing uncommitted files, unmerged branches (each tagged shipped-open vs not-shipped), and unpushed commits — so nothing is silently lost. If a repo was already tidy, say so in one line.

## Pipeline Steps

Run these steps sequentially. Each step depends on the previous one succeeding. If any step fails, stop and report the error clearly — don't try to power through.

### Step 0: Read AGENTS.md and learn the repo's conventions

Before doing anything else, load the project's conventions. This is non-negotiable — it's how the skill respects the project instead of imposing a flow on it.

```bash
# Read AGENTS.md first — it is the authoritative convention file. Check common locations.
cat AGENTS.md 2>/dev/null || cat .agents/AGENTS.md 2>/dev/null || cat docs/AGENTS.md 2>/dev/null || echo "No AGENTS.md found"

# Also read CLAUDE.md if present — secondary source, useful for deploy/commit details.
cat CLAUDE.md 2>/dev/null || cat .claude/CLAUDE.md 2>/dev/null || echo "No CLAUDE.md found"
```

Then inspect the actual repo so your branch decisions match reality, not assumptions:

```bash
git branch -a                                   # local + remote branches
gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null  # a hint, not gospel
gh pr list --state open --json number,title,headRefName,baseRefName 2>/dev/null  # existing PRs / branches
git log --oneline -5                            # recent commit style
```

**What to extract:**
- **Shipping conventions from AGENTS.md** — branch naming, the integration/target branch, new-branch-vs-push-to-existing preference, commit style, PR base, deploy steps. **Whatever AGENTS.md says overrides the defaults in this skill.** Note in one line if you're following an AGENTS.md override.
- **The real branch layout** — which branches exist (primary, secondary, feature branches), so Step 1.5 resolves correctly.
- **Existing branches/PRs** — so you don't collide names or duplicate an in-flight PR.

If neither AGENTS.md nor CLAUDE.md exists, proceed with this skill's defaults — and remember Step 1.5 / Step 6B may offer to create AGENTS.md to record what you do.

### Step 1: Assess the situation

Run these in parallel to understand the current state:

```bash
git status          # What's changed (staged, unstaged, untracked)
git diff            # Unstaged changes
git diff --cached   # Staged changes
git branch --show-current  # Where you are now
```

**Branch check**: **Never push or commit directly to the primary branch (`main`/`master`).** Being *on* it is fine — Step 1.5 cuts a new branch and moves there. You don't need to ask permission to start.

**Nothing to commit**: If there are no changes (no diff, no untracked files), say so and stop.

**Inventory uncommitted work**: Catalog all uncommitted changes — staged, unstaged, and untracked. In session-only mode, you need to distinguish session files from other work. List changes grouped by:
1. **Session files** (files you touched in this conversation)
2. **Other uncommitted changes** (not being shipped — these stay in the working tree untouched)

**Scope — session-only (default) vs all**: Default is session-only; only `/ship all` sweeps the whole tree.

- **Session-only (default, or `/ship this chat`/`here`)**: Only ship changes created or modified during THIS conversation. Review your conversation history for files touched via Read, Write, Edit, or Bash tools. Cross-reference with `git status` — only consider files that appear in BOTH your session history AND the uncommitted changes list. Then, per the **"Cherry-pick the session's own changes"** section above, classify each session file as **whole-session** (its entire working diff is yours) or **mixed** (it also carries hunks you didn't make this session) — `git diff <file>` against what you know you edited. This classification decides how Step 3 stages it (whole file vs. session hunks only). **If a mixed file's session hunks can't be cleanly isolated from the foreign ones, stop and flag per that section — do not ship a partial guess.** **Don't ask for confirmation** otherwise — give a one-line summary and proceed. Group the session changes into one commit (bullets if it spans a few areas). Note any non-session changes left behind: "Note: X other files (or foreign hunks) have uncommitted changes not included in this commit. They remain in your working tree."
- **All changes (`/ship all`)**: ALL uncommitted changes are candidates — this diverts to the **Orchestrated ship** (Phase 1–3), which may split them across several PRs. Its laziness-gate fallback for a tiny tree stages everything with `git add -A`.

If the changes span multiple unrelated concerns, suggest grouping them into a single commit with bullet points. Only split into multiple commits if the user explicitly asks.

**Sensitive file check**: Scan the changed/untracked files for anything that looks like secrets:
- `.env`, `.env.*`
- Files with `secret`, `credential`, `key`, `token`, `password` in the name
- `*.pem`, `*.key`

If found, list them and ask the user to confirm before staging. Do NOT auto-stage these. (This legitimately pauses the autonomous default flow — a leaked secret is worth interrupting for.)

**Junk / test-data check**: Before staging, scan the changes — **especially untracked files** — for things that look like they shouldn't be committed. This is where scratch artifacts and one-off test data get caught before they pollute the repo. Common tells:

- **OS / editor cruft**: `.DS_Store`, `Thumbs.db`, `*.swp`, stray `.idea/` or `.vscode/`.
- **Debug / scratch captures**: screenshots and recordings dropped at the repo root or in scratch dirs (`*.png`, `*.jpg`, `*.gif`), `*.log`, HAR / trace dumps (`*.har`, `trace.zip`), snapshot notes and session scratch (`*-snapshot*.md`, `*-before*.png`, `review-NN-*.png`, `*-adhoc*`, ad-hoc `.md`/`.yml` dumps), and tool scratch dirs (`.playwright-mcp/`, `.harness-backup/`, `.e2e-adhoc/`, `tmp/`, `scratch/`).
- **Build / dependency output**: `node_modules/`, `dist/`, `build/`, `.next/`, `coverage/`, `__pycache__/`, `*.pyc`.
- **One-off test / seed data**: DB dumps (`*.sql` dumps), large generated JSON/CSV blobs, fixture files that look session-specific.

Judge by **intent, not extension** — a `.png` under `src/assets/` is a real asset; twenty `review-*.png` at the repo root are scratch. When unsure, flag it rather than silently shipping it. Anything already matched by `.gitignore` won't show up here — this is for the stuff that slipped past it.

**If any is found, this legitimately pauses the autonomous default** (same footing as the secret check). List them grouped by category, then offer three choices — don't auto-decide, and **never delete anything yourself without an explicit OK** (top-of-file guardrail):

1. **Exclude from this ship** (default suggestion) — stage the real changes and leave the flagged files in the working tree. For the ones that clearly never belong in git (`.DS_Store`, tool scratch dirs, build output), also offer to add them to `.gitignore` in the same commit so they stop reappearing.
2. **Delete them** — only on the user's confirmation; you run the `rm` / `git rm`, they made the call.
3. **Ship them anyway** — they're intentional (e.g. docs screenshots); proceed as-is.

If the user just says "clean it up" without specifying, take option 1: exclude the obvious cruft, `.gitignore` the never-belongs-in-git ones, and ship the rest.

### Step 1.5: Resolve branches and cut the new branch

Apply the **Branch model** (filtered through any AGENTS.md override from Step 0). The output of this step is two concrete branch names — the **primary** (never targeted by default) and the **secondary** (the PR base) — plus the **new branch** you'll commit onto.

**Resolve the primary branch**: `main` or `master` (prefer `main`).

**Resolve the secondary branch** using the priority order from the Branch model: AGENTS.md-named → user-named (`to <branch>`) → an existing `develop`/`dev`/`development`/`staging` → fall back to the primary branch if no secondary exists (state this in one line).

**Now choose the head branch:**

- **Auto-continue an existing ship branch (check this FIRST).** If you're currently on a branch that is **neither** the primary **nor** the secondary branch **and** that branch already has an open PR (from the `gh pr list` output in Step 0, match `headRefName` to the current branch), the user is almost certainly iterating on work they already shipped — so **treat this run as `from here`**: keep the current branch as the head, don't cut a new one. This is what makes "ship → tweak → ship again" land on the **same branch and same PR** instead of spawning a duplicate. State it in one line: "Continuing existing branch `ship/foo` (open PR #18) — updating it rather than cutting a new branch." (If the user explicitly passed a mode that cuts a new branch, or there's no open PR for the current branch, fall through to the default below.)
- **Default → cut a new branch.** Branch off the up-to-date secondary branch so the PR diff is clean:
  ```bash
  git fetch origin
  git checkout -b <new-branch> origin/<secondary-branch>   # carries uncommitted changes along
  ```
  Name the new branch per AGENTS.md's convention if it defines one; otherwise use `ship/<slug>` where `<slug>` is a short kebab-case summary of the change (e.g. `ship/auth-waterfall-fix`). If checking out from `origin/<secondary>` would conflict with the working-tree changes, branch off the current HEAD instead (`git checkout -b <new-branch>`) and note it — never discard changes to make the checkout "work."
- **`from where I am` / `from here`** → keep the **current branch** as the head; don't cut a new one. (Skip this override if you're on the primary branch — fall back to cutting a new branch.) **Orphan guard:** if the current branch's most recent PR is already **MERGED or closed** (not open), do **not** reuse it — pushing more commits onto a dead head strands them; they never reach `<secondary>`. Cut a fresh branch off `origin/<secondary>` and open a new PR instead (same fall-through as auto-continue). Only reuse the current branch when it has **no PR yet** or an **open** one.
- **AGENTS.md says "push directly to the secondary branch" (no per-change branch)** → honor it: check out the secondary branch and commit there, exactly as AGENTS.md prescribes. This is the project overriding the default.

**Find existing branches/PRs to avoid collisions/duplicates.** If a `from here` ship or an AGENTS.md "push to existing branch" flow targets a branch that already has an open PR, your push updates that PR — don't open a second one (handled in Step 5).

**Guardrail reminder:** `git checkout -b` carries uncommitted changes along without discarding anything. If a switch would actually conflict, stop and surface it (per the top-of-file guardrail). Never `reset`/`restore`/`stash`/`clean` to force it.

### Step 2: Generate the commit message

If the user provided a message override, use it as the summary line. Otherwise, analyze the diff to write one.

1. Read the full diff (staged + unstaged combined).
2. Identify the *intent* — feature, bug fix, refactor, config, docs?
3. Write a summary line: imperative mood, under 72 chars, describes the *why* not the *what*.
   - Good: "Fix auth waterfall by returning user profile from refresh endpoint"
   - Bad: "Update auth.service.ts and auth.tsx"
4. Add bullet points for the key changes.
5. End with the co-author line.

**Format:**
```
Summary line here

- Detail about change 1
- Detail about change 2

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

Match the project's existing style (`git log --oneline -5`) and any commit convention in AGENTS.md.

### Step 3: Stage and commit

1. **Staging depends on the scope mode:**
   - **Session-only (default)**: stage ONLY this session's own changes, at **hunk granularity** (see "Cherry-pick the session's own changes"). Never `git add -A`.
     - **Whole-session files** (entire diff is yours, or created this session) → stage by explicit path: `git add <file1> <file2> ...`.
     - **Mixed files** (also carry non-session hunks) → stage only *your* hunks, leaving the foreign ones unstaged in the tree. `git add -p` is interactive and may not run in this harness, so prefer the patch route: assemble a patch of just the hunks you made this session (you know them from your Edit/Write history) and `git apply --cached <patch>`. Then **verify**: `git diff --cached <file>` shows only your hunks, and `git diff <file>` still shows the foreign ones left behind.
     - **Inseparable** → do NOT stage a partial guess; **stop and flag** (clean cherry-pick impossible without other unmerged changes), per the cherry-pick section.
     List the files you staged, and for any mixed file note that only the session hunks were staged.
   - **All changes (`/ship all`, or its laziness-gate fallback)**: `git add -A`. Only exclude files that fail the sensitive-file check, that the junk / test-data check flagged for exclusion, or that the user asked to leave out (stage explicit paths, or `git add -A` then `git reset <flagged paths>`).
2. Commit using a HEREDOC to preserve formatting:
```bash
git commit -m "$(cat <<'EOF'
Your commit message here

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```
3. Run `git status` after to confirm the commit succeeded.

### Step 3.5: Pull the latest base into the head branch before pushing

The point is to build the PR on the **up-to-date base** so the diff is clean and the merge stays conflict-free.

- **Freshly cut branch (default flow)**: Step 1.5 already rooted it on the up-to-date base via `git checkout -b <new-branch> origin/<secondary-branch>` (right after `git fetch origin`), so there's nothing to sync — **skip this step.**
- **Existing branch (`from here`, auto-continue, or an AGENTS.md push-to-existing flow)**: that branch may be behind the base. Fetch and merge the latest base in before pushing:
  ```bash
  git fetch origin <secondary-branch>
  git merge origin/<secondary-branch> -m "Merge <secondary-branch> into <head-branch>"
  ```

Use a **plain merge** (not rebase/reset) to honor the guardrail — it adds a merge commit rather than rewriting history. On a clean merge, continue to Step 4. On conflicts, do NOT discard or force past them: list the conflicting files, stop, and ask the user to resolve (or resolve them manually). Never `reset`/`checkout --`/`stash`/`clean`/force to make the merge "work."

### Step 4: Push the branch

Push the head branch Step 1.5 resolved — normally the **new branch**:

```bash
git push -u origin <new-branch>
```

If the push is rejected, do NOT force-push. Tell the user and suggest `git pull --rebase origin <branch>` first (relevant when shipping an existing branch with upstream commits — a freshly cut branch shouldn't be rejected).

### Step 5: Open the PR into the secondary branch

**If `no pr` mode is set, skip this step entirely.** The branch is committed and pushed (Steps 3–4), which is all `no pr` asks for. Report the branch and that no PR was opened, then run Step 5.6 (verify — for `no pr` on a fresh branch, "count > 0, no open PR yet" is the expected WIP end state; it still catches a push accidentally landing on an already-merged head) and continue to Step 7 (skip Steps 6, 6B). If `review` was also requested, Step 8 still runs — it reviews the diff, not the PR.

**If the head branch already has an open PR** (possible in `from here` / AGENTS.md "existing branch" flows): your Step 4 push already updated it. Refresh its title/body (`gh pr edit <n> --title ... --body ...`) and report its URL. Don't open a duplicate.

**Otherwise create the PR:**

1. Get the commit log and diff between the base and the head:
```bash
git log <secondary-branch>..<new-branch> --oneline
git diff <secondary-branch>...<new-branch> --stat
```

2. **Detect manual production steps that must run on deploy** (see "### Detecting manual production steps" below). If the diff includes a migration/backfill script, a stored-enum/status rewrite, a seed that must be run, a new env var / `VITE_*` flag, or a new scheduled/Celery-beat task, it must be **flagged in the PR body** — the person who merges and deploys can't be expected to spot a migration buried in the diff. If the change needs none, omit the section (don't add empty noise).

3. Write the PR body. Include the `## ⚠️ Manual deploy steps` section **only when Step 2 found any** — otherwise drop it entirely:
```
## Summary
<2-4 bullet points covering what changed and why>

## ⚠️ Manual deploy steps
<!-- Include ONLY if the change needs an action a human must run on production that the
     auto-deploy pipeline (Step 6B) won't do by itself. Give the exact command, when to run
     it (before/after deploy), and what breaks if it's skipped. Omit this whole section if none. -->
- [ ] Run `<exact migration/backfill command>` **after** deploy — <what it does / what breaks if skipped>
- [ ] Set `<ENV_VAR>` in Coolify **before** deploy — <what breaks if missing>

## Test plan
- [ ] Specific thing to verify
- [ ] Another thing to verify
- [ ] Edge case to check

Generated with [Claude Code](https://claude.com/claude-code)
```

4. Create the PR from the new branch into the secondary branch:
```bash
gh pr create --base <secondary-branch> --head <new-branch> \
  --title "Short descriptive title" \
  --body "$(cat <<'EOF'
PR body here
EOF
)"
```

5. Capture and display the PR URL. If Step 2 flagged manual deploy steps, **repeat them in the chat summary** too — not just in the PR body — so they're impossible to miss.

### Detecting manual production steps

The point of the `## ⚠️ Manual deploy steps` PR section is that the auto-deploy (Step 6B) does **not** do everything: some changes need a human to run something against production. Scan the diff for these tells and, when any hit, list the exact action in the PR body:

- **Migration / backfill scripts** — new or changed files under a migrations path or named for one (`*migration*`, `*backfill*`, `alembic/versions/*`, `prisma/migrations/*`, `drizzle/*`, `supabase/migrations/*`, one-off `scripts/*backfill*.py`). Anything a person must invoke to reshape existing prod data.
- **Stored-enum / status rewrites** — a change to an enum/status value that already exists in the database needs an update over stored rows, not just new code.
- **Seeds that must run** — new/changed `seed*.py` or seed data the deploy won't apply on its own (this repo's `seed.py` SKIPS existing users and does NOT run on boot — so a seed change is a manual step).
- **New env vars / feature flags** — code that reads a new `os.environ[...]` / `process.env.X` / `VITE_*` not already set in prod (e.g. `FRONTEND_URL`, which if unset defaults invite/reset links to `localhost`). The var must be added in Coolify before deploy.
- **New scheduled / Celery-beat tasks** — a periodic task only fires if beat is running and configured; note it.

**Judge by "does prod need a human action the auto-deploy won't do?"** — if yes, flag the exact command and timing; if no (ordinary code/UI/docs change), omit the section entirely. When AGENTS.md's `## Production Deploy` already documents the migration command, cite it in the flag rather than inventing one. When unsure whether a step is needed, flag it — a needless line is cheap; a silent migration is an outage.

### Step 5.4: Auto-flag PR conflicts (runs on every flow)

Right after opening/updating the PR — **before** deciding to merge (Step 6) or hand it to review — ask GitHub whether the PR merges cleanly into the base. This is the only conflict check on the standard flow (the PR is opened and left open, so nothing else would surface a conflict) and it tells the user *why* a merge won't proceed on the `merge` flow.

GitHub computes mergeability asynchronously, so a freshly created PR may report `UNKNOWN`; poll until it resolves:

```bash
for i in 1 2 3 4 5; do
  M=$(gh pr view <number> --json mergeable --jq .mergeable)
  [ "$M" != "UNKNOWN" ] && break
  sleep 2
done
echo "mergeable=$M"
```

- **`MERGEABLE`**: clean — proceed normally.
- **`CONFLICTING`**: the PR **conflicts with the base** — one of the few things that legitimately halts the autonomous flow. Do **not** merge even if `merge` was requested (it will fail). List the conflicting files — `git fetch origin <secondary-branch> && git merge --no-commit --no-ff origin/<secondary-branch>` to see them, then `git merge --abort` (guardrail: **abort**, never reset/force/stash). Leave the PR open, **flag it prominently**, and tell the user which files collide, offering to merge `origin/<secondary-branch>` into the branch and resolve manually.
- **`UNKNOWN` after polling**: not computed yet — report "couldn't confirm mergeability", continue, and if Step 6 auto-merges let the real merge result decide.

### Step 5.5: Fold into the local secondary branch — ALWAYS, automatically

**This runs on every ship that produces a feature branch, whether or not the PR was merged — no prompt.** The one goal: the shipped commit always ends up on your local integration branch and the local feature branch never piles up.

- **Standard flow (PR opened, not merged):** run the fold below directly — do NOT ask.
- **`merge` mode:** already handled — Step 6 syncs the secondary branch (`git pull`) and deletes the head, so local `develop` already carries the shipped commit. Nothing extra to do here.
- **`no pr` mode:** the branch is intentionally kept for more WIP, so skip the fold — this is the single documented exception (the branch is still on-going work, not a finished unit).

**Resolve the local fold target** (this is where the shipped commit lands locally):
1. The resolved **secondary** branch (`develop`/`dev`/`development`/`staging`) if one exists locally or on the remote.
2. If **no** develop/dev-style branch exists at all, fall back to the **primary** branch (`main`/`master`).

After the PR is open, the shipped commit still lives only on the local feature branch. Left alone, every `/ship` leaves another stale local branch behind — the "10 feature branches piling up" problem. So **immediately** fold the change into the local fold-target branch and drop the feature branch:

```bash
git checkout <fold-target-branch>
git merge --ff-only <head-branch>   # local fold-target now carries the shipped commit(s)
git branch -d <head-branch>         # -d only deletes an already-merged branch — safe
```

Both are safe by construction: `--ff-only` fast-forwards or refuses (it never invents a merge commit or touches other work), and `-d` refuses to delete an unmerged branch. If `--ff-only` fails because the local fold-target has moved on, fall back to a plain `git merge <head-branch>`; if that isn't clean, stop and keep the branch — never `reset`/`checkout --`/`stash`/`clean`/force (top-of-file guardrail). Deleting the *local* feature branch is safe while the PR is open — the PR is backed by the pushed `origin/<head-branch>`, which stays put.

**Squash-merge caveat.** If the project squash-merges PRs (check AGENTS.md / the repo's merge strategy), do **not** fold the commit into the local fold-target — the remote will later add a *different* squashed commit and your local branch would diverge. In that case take the tidy-only path automatically: just `git branch -d <head-branch>` now, and `git checkout <fold-target-branch> && git pull` **after** the PR merges. Say in one line which path you took.

**Side effect worth a half-line:** once folded-and-deleted, a later tweak + `/ship` starts a fresh branch/PR rather than auto-continuing this PR (Step 1.5) — which is the point: this run's unit of work is done.

### Step 5.6: Verify the work actually shipped — not orphaned on an already-merged PR

**Runs on every flow that pushed** (standard, `from here`, auto-continue, `no pr`, and each PR in
`/ship all`). Before you report success, prove the commits you just pushed are genuinely on their way
into the base — **not stranded on a branch whose PR already merged**, where a push lands on the remote
head but never reaches `<secondary>`. Pushing "succeeded" and the branch being "mergeable" (Step 5.4)
do **not** prove this; only base-reachability + PR-state does.

The decisive test — commits on the head that the base does **not** yet contain, plus whether an OPEN
PR carries them:
```bash
git fetch origin <secondary-branch>
git rev-list --count origin/<secondary-branch>..<head-branch>                       # commits not yet in base
gh pr list --head <head-branch> --state open --json number --jq 'length'            # open PR carrying them?
```
Read the result:
- **count `0`** → every commit is already in `origin/<secondary>`. **Shipped ✓** (nothing left to carry).
- **count `> 0` with an OPEN PR on this head** → the open PR you just created/updated will carry them
  in. **Shipped ✓.** (In `no pr` mode this is the expected end state — pushed, awaiting a future PR;
  say so explicitly.)
- **count `> 0` with NO open PR — the head's newest PR is MERGED/closed (or there's a merged PR and
  you pushed after it)** → **ORPHANED. Do NOT report success.** The push landed on a dead head; those
  commits will never reach `<secondary>` on their own. **Remediate in this same run:** cut a fresh
  branch off `origin/<secondary>`, cherry-pick the orphaned commits onto it
  (`git log --oneline origin/<secondary-branch>..<old-head>` lists them), push it, open a **new** PR,
  then re-run this check on the new branch until the count is `0` or an open PR covers it.

Why this exists as its own gate: Step 1.5 chooses the branch and Step 5.4 confirms mergeability, but a
branch can pass both, the push can succeed, and the commits can **still** be orphaned if that head's PR
already merged. This base-reachability + open-PR check is the only step that catches "pushed but going
nowhere" — the exact failure where a follow-up commit lands on an already-merged PR head and silently
never ships.

### Step 6: Auto-merge (only if `merge` flag is set)

If `merge` is set, merge the PR into the secondary branch immediately after it exists.

**The merge target is the PR's base (the secondary branch), never the primary branch.** You never push or merge straight onto `main`/`master`.

```bash
gh pr merge <number> --merge --delete-branch
```

Use `--merge` (not `--squash`) unless AGENTS.md specifies a different merge strategy. Pass `--delete-branch` because the head is a short-lived branch — **unless** the head is a long-lived branch (a `from here` ship of a feature branch, or an AGENTS.md "push to develop" flow), in which case omit `--delete-branch`.

After the merge succeeds, sync local and return to the secondary branch (your working tree comes along untouched):

```bash
git checkout <secondary-branch> && git pull origin <secondary-branch>
```

**Always clean up the short-lived head branch after a merge — don't rely on `--delete-branch` alone.** `gh pr merge --delete-branch` removes the branch only when *gh* performs the merge; if the merge already happened another way (you merged it manually, the user clicked merge in the UI, or a release flow merged it), the branch lingers. So after confirming the merge, explicitly sweep the head branch — remote first, then the stale local ref:

```bash
git push origin --delete <head-branch> 2>/dev/null || true   # no-op if --delete-branch already removed it
git branch -D <head-branch> 2>/dev/null || true              # drop the local copy now that it's merged
git fetch --prune origin                                      # clear stale remote-tracking refs
```

This applies **only** to the short-lived ship branch — **never** delete a long-lived branch (`develop`/`dev`/`staging`, a `from here` feature branch, or the primary branch). When in doubt, only delete a branch matching the name you cut in Step 1.5.

If the merge fails (conflicts, required checks pending), report the error and leave the PR open. Don't retry. Then proceed to Step 6B.

### Step 6B: Production deployment (only after successful merge)

Run the project's production deployment pipeline. Every project differs — Railway, Vercel, EC2; Prisma/Drizzle/raw-SQL migrations; cache invalidation, CDN purges, seeds. Read the playbook from the project's `AGENTS.md` (fall back to `CLAUDE.md`).

#### 6B.1: Look for deploy instructions

Search for a deploy section in `AGENTS.md` (then `CLAUDE.md`) — `## Production Deploy`, `## Deployment`, `## Deploy Pipeline`, `## Production`, or similar.

```bash
cat AGENTS.md 2>/dev/null | head -200
cat CLAUDE.md 2>/dev/null | head -200
```

You want answers to: what migrations run and how? what platform, and does it auto-deploy? health-check URLs? seed/bootstrap steps? post-deploy verification?

#### 6B.2: If no deploy section exists — investigate, then ask

Don't guess or skip. Investigate the codebase first — run these in parallel:

```bash
cat README.md 2>/dev/null | head -300
cat docs/deployment.md docs/DEPLOYMENT.md 2>/dev/null | head -200
ls vercel.json fly.toml railway.toml railway.json Procfile render.yaml \
   netlify.toml amplify.yml appspec.yml docker-compose*.yml Dockerfile \
   .github/workflows/*.yml 2>/dev/null
cat package.json 2>/dev/null | grep -E '"prisma"|"drizzle"|"knex"|"typeorm"|"sequelize"|"migrate"|"supabase"'
ls prisma/migrations drizzle supabase/migrations 2>/dev/null
ls .env* 2>/dev/null
grep -r "health" --include="*.ts" --include="*.js" --include="*.py" -l 2>/dev/null | head -5
cat package.json 2>/dev/null | grep -A2 '"deploy"\|"migrate"\|"seed"\|"build"'
```

Synthesize and decide:
- **High confidence** (hosting config + migration tooling + deploy/health scripts): draft the `## Production Deploy` section, **write it to AGENTS.md**, tell the user what you added, and execute it.
- **Moderate confidence** (gaps): draft what you know, ask only about the gaps, then write to AGENTS.md and execute.
- **Low confidence** (almost nothing found): tell the user what you looked for, ask targeted questions framed around what you *didn't* find, then record the answer in AGENTS.md.

Section format to write into AGENTS.md:
```markdown
## Production Deploy

Merging to `<secondary-branch>` (or `main`) triggers auto-deploy on [platform].

### Database migrations
```bash
[migration command]
```

### Verify deployment
```bash
[health check command]
```

### Other steps (if any)
[description and commands]
```

Read the section back to the user, then execute it. On future `/ship merge` runs it already exists.

#### 6B.3: Execute the deploy playbook

Follow the instructions step by step. Run each command, check output, report results.
- **Run steps sequentially** — migrations before health checks, seeds before verification.
- **Stop on failure** — a failed migration likely means the new code breaks against the old schema. Report immediately.
- **Check for relevance** — if the playbook mentions migrations but the diff touched none, note "No pending migrations" and skip.
- **Report results clearly** — for each step, say what you ran and what happened.

### Step 7: Offer to ship remaining uncommitted changes

This catches work not included in the commit — things changed outside this conversation. Skipping this step is how work gets lost.

```bash
git status
```

If changes remain:
1. **List them clearly** with a brief summary of each.
2. **Ask**: "These files have uncommitted changes that weren't part of this session. Want me to ship them too in a separate branch/commit?"
3. If yes, repeat Steps 1.5–5 for the remaining changes.
4. If no: "These changes are still in your working tree — they'll be there next time."

Runs regardless of scope mode and merge mode. It's a safety net.

### Step 8: Post-ship review (only if `review` flag is set)

Run a code review on the shipped diff after the pipeline completes. Works off the diff, so it runs whether or not a PR was opened.

```bash
git diff <secondary-branch>...<head-branch>
```

Invoke the `senior-engineer` skill (via the Skill tool) to review the diff — PR-level review: structured feedback with severity tiers, actionable suggestions, issues worth flagging before merge. If the review surfaces important issues, address them in a follow-up commit.

### Step 9: Post-ship cleanup (only if the `cleanup` suffix is set on a ship flow)

Runs when `cleanup` rode along on a real ship — canonically `/ship merge cleanup` — as the very last action, after the merge, deploy (Step 6B), and any `review` (Step 8) have finished. This is **not** the bare `/ship cleanup` tidy mode; it is a straight handoff to the standalone tidy skill:

**Invoke `Skill(cleanup)`** and let it run its own procedure — the worktree-aware fan-out that commits/pushes/merges any still-pending work across the workspace before pruning spent worktrees and merged branches. Don't reimplement it here; just hand off once the ship is done and green.

- **Gate on a successful merge.** If the merge failed or was skipped (`no pr`, conflicts, checks pending), there's nothing safe to tidy — say cleanup was skipped and why, and don't invoke it.
- **Order:** merge → deploy → review (if set) → **cleanup last**, so tidying never races an unfinished step.

## When the user wants a different flow

This is core to the skill, not an edge case. The default pipeline above is a *starting point*, not a mandate. If the user says anything that contradicts the default — different branch naming, push-to-existing-branch instead of new-branch, a different PR base, squash instead of merge, skip the new branch entirely — **do it their way for this run, no friction.**

Then offer to make it stick:

> Want me to record this in AGENTS.md so `/ship` follows it automatically next time?

If yes, write a concise shipping convention into AGENTS.md (create a `## Shipping` / `## Ship Convention` section if none exists). Keep it specific and machine-readable for the next run — e.g.:

```markdown
## Shipping

- Branch naming: `feat/<ticket-id>-<slug>` off `develop`
- PR base: `develop` (never PR into `main` directly)
- Merge strategy: squash
- Deploy: see ## Production Deploy
```

From then on, Step 0 reads this and the convention overrides the skill's defaults — the project has taught `/ship` how it ships.

**Record the branch model, not just overrides.** This isn't only for when the user contradicts a default. Any time you **resolve, are told, or decide** a repo's branch/shipping model and `AGENTS.md`/`CLAUDE.md` doesn't already state it, write it down — especially the branch model itself:

- Which branches exist: the **primary** (`main`/`master`) and the **integration** branch (`develop`/`dev`/`staging`/`feature`), if any.
- The **branch-naming** convention (e.g. `ship/<slug>`).
- Whether work flows through an **integration branch before `main`** (two-tier), or **ships straight to `main`** (single-tier, no integration branch).
- **Merge strategy** (merge vs. squash) and the **PR language** if non-English.

The single most important fact to capture is that last branch-model question — two-tier (`develop → main`) vs. straight-to-`main` — because it decides both the default PR base and what `/ship to main` does. If a `## Shipping` section already documents this (as `evo-books-studio` and `nxbgd-sbt-digital` do), **don't duplicate it — just follow it.** The goal is that the *next* run reads the convention instead of re-deriving or re-asking it.

## Error handling

- **On the primary branch (`main`/`master`)**: don't commit/push to it. Cut a new branch off the secondary branch and ship from there (Step 1.5). No need to ask.
- **No secondary branch exists (only `main`)**: cut the new branch and PR it into the primary branch; say so in one line (Step 1.5).
- **Push rejected**: never force-push. Suggest `git pull --rebase origin <branch>`, then push.
- **PR conflicts with base (Step 5.4, `mergeable=CONFLICTING`)**: don't auto-merge (even if requested). List the conflicting files, flag it, leave the PR open for the user to resolve.
- **gh CLI not authenticated**: tell the user to run `gh auth login`.
- **No changes to commit**: "Nothing to ship — working tree is clean." and stop.
- **AGENTS.md conflicts with the live repo** (names a branch that doesn't exist): trust the live repo, surface the mismatch.
- **No deploy instructions anywhere**: don't guess. Investigate, then ask, then record in AGENTS.md (Step 6B.2).

## Tone

Be brief and action-oriented. The user said "ship it" — they want speed, not a lecture. Report what you did in a compact summary at the end.

**End with a summary like:**

Standard mode (no merge):
```
Shipped:
- Branch: ship/auth-waterfall-fix (off develop)
- Committed: "Fix auth waterfall..." (5 files)
- Pushed and opened PR #18 (ship/auth-waterfall-fix → develop): https://github.com/...
- Auto-folded into local develop and deleted ship/auth-waterfall-fix — local branches stay tidy (PR still open on remote)
```
(This fold is automatic on every feature ship, whether or not the PR merged; the only skip is `no pr` mode, where the branch is kept for WIP.)

If the diff needed manual deploy steps, add a flagged line so it's visible in chat too:
```
- ⚠️ Manual deploy step (flagged in PR): run `python -m app.migrations.backfill_orgs` AFTER deploy — backfills org_id on existing iam_users
```

`no pr` mode:
```
Shipped (no PR):
- Branch: ship/auth-refactor (off develop), pushed
- Committed: "WIP auth refactor..." (5 files)
- No PR opened — run /ship when ready to open it into develop
```

Merge mode:
```
Shipped, merged & deployed:
- Branch: ship/auth-waterfall-fix → develop
- Committed: "Fix auth waterfall..." (5 files)
- PR #18 merged into develop
- Deploy: [summary of each deploy step result]
```

If following an AGENTS.md convention, add a line at the top: `- Convention: followed AGENTS.md (PR base develop, branch feat/<ticket>)`.

For review mode, append after the shipping summary:
```
Running code review on shipped changes...
```
Then present the senior-engineer review output inline.
