---
name: cleanup
description: "Tidy git worktrees and feature branches AFTER work is done — safely, by checking before deleting, never deleting first. Triggers on 'clean up', 'tidy', 'tidy branches', 'clean up worktrees', 'dọn dẹp', or any similar phrase. DEFAULTS to only THIS session's worktrees/branches (the ones this session created/cut/pushed) — other stale worktrees are reported, not touched; widen to the whole workspace only when the user explicitly asks ('clean up everything/all worktrees/every branch/across the codebase') or names another target. FANS OUT one 'cleaner' subagent per worktree (parallel, not one-by-one): it first surveys the codebase (which repos, how many worktrees, which branches/PRs), then dispatches a cleaner per worktree that runs check → report → act. Each cleaner verifies the worktree is fully committed (auto-commits dirty work ONLY after gating it — never commits junk, secrets, or stale/superseded/broken changes; flags those instead), pushed AND actually reaching develop (the decisive gate: `git rev-list --count origin/develop..<branch-head>` must be 0, OR the non-zero commits sit under an OPEN PR — commits pushed onto an ALREADY-MERGED/closed PR head are ORPHANED, never reach develop, and hard-block deletion until re-shipped via a fresh branch + new PR; local preview-sync is NOT proof of shipping), and cleanly merged into local develop (preview sync — merging now if not; each cleaner resolves its OWN merge conflicts independently, aborting + reporting only on a direct clash), classifies PR status and suggests a PR only when one is genuinely needed, then **reports the full plan and waits for the user's explicit confirmation** — and ONLY AFTER that yes removes the worktree and deletes the branch with `git branch -d` (never -D). After the worktrees are removed, it **reconciles local `develop` with `origin/develop`** — fetch, then fast-forward local `develop` up to the remote (or a merge if the two genuinely diverged), never a reset/rebase/force and never discarding local-only preview commits — so the primary checkout's `develop` ends level with what's shipped. Conflict policy: resolve conflicts; ignore unrelated live WIP on the primary checkout (never stash/discard); cancel and report + suggest PR-or-wait ONLY on a direct conflict with your worktree's changes. Never resets, force-pushes, `-X theirs`, `-D`, or discards anyone's uncommitted work. Does NOT ship new work like /ship — it only lands finished work back and tidies. Has a second REMOTE-BRANCH mode (triggered by 'clean up/prune/tidy remote branches', 'dọn remote branch') that also fans out one subagent per remote branch: it checks ALL remote branches, and — again only after presenting the plan and getting the user's explicit confirmation — deletes only those provably safe (fully merged into develop AND nothing pushed since — `git rev-list origin/develop..origin/<branch>` == 0), and notes the rest — branches needing a merge-back/PR before deletion vs stale ones — verifying the code is good and not stale before any merge, never deleting a protected or open-PR branch, never force-deleting. Has a THIRD REDUNDANT-FILE mode (triggered by 'clean up redundant files', 'remove unused images', 'delete orphaned assets', 'dọn file thừa/ảnh thừa') that sweeps the tree for scratch artifacts, provably-orphaned assets (zero references anywhere), and exact duplicates — NEVER product assets like tracked images/data (e.g. books/ ground-truth) — sorts them into three buckets, and after presenting the plan and getting explicit confirmation deletes only the confirmed set (git rm tracked, rm untracked); the default worktree mode also surfaces stray-file candidates report-only. AGENTS.md conventions override these defaults."
version: 1.7.0
---

# /cleanup — Survey, then fan out cleaners to tidy worktrees, branches & stray files

You tidy the workspace **after** feature work: converge finished worktree commits into local
`develop`, then remove spent worktrees and merged branches. The one rule that governs everything:

> **Check → report → confirm → act. Never delete first, never delete unasked.** Nothing (a
> worktree, a branch, a commit) is removed until **(a)** you've verified the work it holds is
> committed, pushed, and merged into local `develop`, **and (b)** you've shown the user the full
> plan and they've **explicitly confirmed the deletion.** If the verification is missing, you fix
> or flag it; if the confirmation is missing, you stop at the report and delete nothing. You never
> let work hang and then delete it, and you never remove a branch or worktree without an explicit
> go-ahead.

This skill **fans out** — it does **not** grind through worktrees one-by-one. First it surveys the
whole workspace, then it dispatches **one "cleaner" subagent per worktree**, all working at once.

## Three modes

`cleanup` runs in one of three modes — all **survey first, then act only after a gated confirm**:

- **Worktree cleanup (default)** — plain `clean up` / `tidy` / `dọn dẹp`. Tidies **local worktrees
  and branches**: converge finished worktree work into local `develop`, then remove spent worktrees
  and safely-merged local branches. Everything below through "Primary-merge conflict policy." Its
  final report also **surfaces stray-file candidates** it noticed (report-only — it deletes files
  only when the user asks, via the file mode below).
- **Remote-branch cleanup** — triggered when the user names **remote branches** ("clean up remote
  branches", "prune remote branches", "tidy the remotes", "dọn remote branch"). Sweeps **all remote
  branches**, deleting only those provably safe (fully merged into `develop`, nothing pushed since)
  and noting the rest. See "## Remote-branch cleanup mode".
- **Redundant-file & image cleanup** — triggered when the user names **files or assets** ("clean up
  redundant files", "remove unused images", "delete orphaned assets", "dọn file thừa / ảnh thừa").
  Sweeps the tree for scratch, provably-orphaned, and duplicate files — never product assets —
  reports three buckets, and deletes only the confirmed set. See "## Redundant-file & image cleanup
  mode".

## Scope — this session's work by default

**Default: tidy only what THIS session created or touched — never the whole workspace.** A cleanup
run right after a build should remove *that build's* worktrees and branches and leave every other
worktree/branch on the machine untouched. Reconstruct the session scope from your own conversation
history:

- worktrees you created this session (`git worktree add …`),
- the `ship/<slug>` branches you cut,
- the repos you committed/pushed in this session.

Only those are **in scope**. Phase 1 still *enumerates* everything (read-only), but the set you
actually dispatch cleaners for and delete is the **in-scope subset** — session-only unless widened.
A stale worktree from some other session is **reported, not touched**.

**Widen only when the user explicitly asks** — "clean up **everything** / **all** worktrees / **every**
branch / **across the whole codebase**", or when they **name** a specific other worktree / branch /
repo (including a repo living elsewhere on the device). Then tidy that broader set (still check →
report → confirm → act).

**Can't reconstruct the session scope** (fresh session, no build history, cleanup opened cold)? Don't
default wide — survey what exists, then **ask** which to tidy (this session's `ship/*` only, or all
stale ones), and act on the answer. Never fan out across every worktree in the workspace just because
they're there.

## Two things that override everything below

1. **AGENTS.md is the source of truth.** Read the project's `AGENTS.md` (and `CLAUDE.md`) before
   touching git. If it defines the branch model (which branch is integration — usually `develop`;
   which is production — usually `master`/`main`), worktree/branch naming (e.g. `ship/<slug>`),
   commit language (e.g. Conventional Commits + Tiếng Việt), or its own cleanup rules, **that wins
   over this skill's generic defaults.** This project's `AGENTS.md` already documents the worktree
   workflow and a cleanup procedure — follow it.
2. **Git safety is absolute — never lose code.** Never `reset`/`reset --hard`, `checkout --`,
   `restore`, `stash`, `clean -f`, force-push, `-X theirs`, or `git branch -D` to "get unstuck."
   Uncommitted edits in the **primary** checkout may be the user's own work or another session's —
   they are not yours to remove, hide, or overwrite. Preserve them.

## What cleanup is NOT

- **Not `/ship`.** It does not open new "ship" PRs, push new feature work, or promote to
  production. It only lands *already-finished* worktree work back into local `develop` and tidies.
  When a change genuinely needs review it **suggests** a PR; it doesn't create ship PRs on its own.
- **Not a discard.** "PR already merged" does **not** mean "everything after it is done" — commits
  pushed after a merge are a new change set (suggest a new PR), never something to silently delete.
- Never deletes a worktree or branch that still holds **unmerged or unpushed** local work.

---

## Phase 1 — Survey (main thread, read-only)

Build the work list before dispatching anyone. A workspace may hold several independent repos
side by side — treat each separately; **a cleaner never spans two repos.** Survey is read-only over
whatever exists, but **what you tidy is the in-scope subset** (see "## Scope" above): the repos this
session actually worked in by default, widening only when the user asks or names another target. When
the user **does** point cleanup at a repo living elsewhere on the device, resolve its root (`git -C
<target-dir> rev-parse --show-toplevel`) and tidy it against **its own** `develop` / primary checkout,
exactly like the session repo — being in a different directory changes nothing. For each in-scope repo:

```bash
git -C <repo> worktree list --porcelain          # every linked worktree + its branch
git -C <repo> branch -vv                          # local branches, upstream/ahead-behind
git -C <repo> for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads
gh -R <owner/repo> pr list --state all --json number,headRefName,state,mergedAt 2>/dev/null
```

From this, list: each repo, its worktrees (path + branch), which branches have open/merged/no PR,
and the resolved integration branch (`develop`) and production branch (`master`/`main`). Also note
plain merged `ship/*` branches with **no** live worktree — those are prune candidates too.

If `gh` is unauthenticated or the repo has no GitHub remote, **skip PR classification** (note it)
and still tidy from git state alone — never block cleanup on a missing `gh`.

If there are no worktrees and no stale merged branches, say "already tidy" and stop.

## Phase 2 — Fan out one cleaner per worktree

Dispatch **one subagent per worktree, in parallel** (a single message with multiple `Agent`
calls). Each cleaner gets a brief carrying the Phase-1 survey for its repo, its worktree path +
branch, the integration/production branch names, the PR status you already found, and the commit
convention — so its first action is acting on *its* worktree, not re-surveying.

**Concurrency rule (one index per repo):** a worktree's own checks/commit/push are worktree-local
and safe to run fully in parallel. But the **merge into the primary checkout's `develop`** writes
the *shared* primary index — so within a single repo, only one cleaner performs that primary merge
at a time (serialize the primary-merge step per repo; across different repos it's fully parallel).
Simplest safe shape: cleaners do all worktree-local work concurrently and each takes the repo's
primary-merge step in turn.

### Each cleaner's procedure — converge and report (a cleaner never deletes)

**Step 1 — Committed? Verify the dirty work is *real, current* work before committing — never
commit garbage to the remote.** No leftover staged/unstaged/untracked *task* work in the worktree.
- Dirty → **before auto-committing, gate the changes:**
  - **Junk / scratch → exclude, don't commit.** Screenshots, `*.log`, HAR/trace dumps, `.DS_Store`,
    tool scratch dirs, build output (`dist/`, `node_modules/`, `__pycache__/`), one-off test/seed
    blobs (same tells as `/ship`'s junk check). Judge by intent, not extension.
  - **Secret → flag, never commit.** `.env`, credentials, keys, tokens.
  - **Stale / superseded / broken → flag and report, don't commit.** Confirm the diff is still live
    task work, not an abandoned or already-done experiment:
    - **Base outdated?** How far is the worktree branch behind `develop` —
      `git -C <worktree> rev-list --left-right --count develop...HEAD`. Badly behind (the edits
      target old code) → don't blind-commit; report it (and, if the edits are still wanted, they
      belong on a branch rebuilt off current `develop`, not committed as-is).
    - **Already done elsewhere?** `git -C <worktree> diff develop -- <changed paths>` — if it shows
      nothing new, the change is already in `develop` (duplicate/superseded) → don't commit it.
    - **Half-applied / broken / unrelated** to the branch's purpose → flag rather than committing a
      broken state.
    On any of these, **do NOT auto-commit; report what looks stale/duplicate/junk and why**, and
    leave the worktree in place for a human call — don't delete it.
  - **Real, current task work →** auto-commit in the worktree (Conventional Commits + the project's
    language per AGENTS.md).
- Never delete the worktree while dirty work is unresolved.

**Step 2 — Pushed, AND every commit actually on its way into `develop`?** Two things must hold, and
the second is the trap that gets missed. **Pushed alone is NOT "shipped."**
- **Pushed.** Every commit is on the remote branch. Push from the worktree if unpushed (`git push`,
  add `-u` if no upstream; **never force-push**).
- **Reaching `develop` through an OPEN PR — not stranded on an already-merged one.** The decisive
  test is which of the branch's commits `origin/develop` does **not** yet contain:
  ```bash
  git -C <repo> fetch origin <integration>                          # refresh origin/develop first
  git -C <repo> rev-list --count origin/<integration>..<branch-head>
  ```
  - **`0`** → every commit is already in `origin/develop`. **Truly shipped ✓.**
  - **`> 0` with an OPEN PR on that head** → fine — the open PR will carry them in. Leave the branch
    in place until the PR merges; do **not** delete it yet.
  - **`> 0` with the PR already MERGED/CLOSED, or no PR at all** → **ORPHANED — hard blocker.** These
    commits were pushed *after* the PR merged (or never had a PR); pushing more onto a merged head is
    a dead end — they will **never** reach `develop` on their own. Do **NOT** count the branch as
    shipped and do **NOT** let Phase 3 delete it. The commits are a **new change set**: cut a fresh
    branch off current `origin/<integration>`, cherry-pick them over, and open a **new PR** (that is
    a `/ship`-style action — this skill *suggests/hands it off*, it doesn't silently drop the work).
    Report it as **orphaned-after-merge** with the exact commits:
    `git -C <repo> log --oneline origin/<integration>..<branch-head>`.

> **Why this gate exists:** a branch showing "pushed ✓" and even preview-synced into *local* `develop`
> can still be carrying commits that never landed on `origin/develop`, because its PR merged *before*
> those commits were pushed. Local preview-sync (Step 3) is a convenience, **not** proof of shipping —
> only `rev-list origin/<integration>..<branch-head> == 0` (or an OPEN PR that will make it 0) proves
> the work is safe to tidy away.

**Step 3 — Cleanly merged into local `develop`?** Every commit from the worktree must already be in
the primary checkout's local `develop` (preview sync). If not, **merge it now** (primary-merge
step, conflict policy below), then `git -C <primary> checkout develop`. If production was promoted,
also merge into local `master`.
- **The primary checkout must always end on `develop`.** The merge destination is always `develop`
  (never a feature branch), whatever branch the primary happened to be on when cleanup started;
  finish with `git -C <primary> checkout develop` so localhost previews from it. Ideally the primary
  sits on `develop` at all times — if you found it on something else, leave it on `develop`.
- **You own conflict resolution end-to-end — handle it yourself.** A cleaner is autonomous on its
  own worktree: when the merge conflicts, *you* resolve the diverged-commit hunks, and *you* make
  the abort-and-report call on a direct clash (conflict policy below). Do **not** punt a routine
  merge conflict back to the orchestrator or leave it half-done for someone else — each worktree's
  conflict is that cleaner's job to finish or to cleanly abort. Only genuinely undecidable
  conflicts (needs a human product call) get surfaced up, with the merge safely aborted first.

**Step 4 — PR / remote-branch status → suggest a PR only when needed:**

| Situation | Action |
|---|---|
| Open PR exists; new commits are just follow-ups on that same head | Fine — push to that PR; **no new PR** |
| Remote branch has commits but **no PR**, or it diverged from `develop` and needs review | **Suggest** opening a PR into `develop` |
| PR already merged, but the worktree has **more** commits after the merge | New change set → **suggest a new PR**; don't pretend the old PR covers them |
| Pushed and already covered by an open (or just-updated) PR | Don't nag about PR creation |

**Step 5 — Report the tidy plan back to the orchestrator; a cleaner deletes nothing.** Once Steps
1–3 pass, the worktree is *ready* to remove — but the actual removal happens once, on the main
thread, and only after the user confirms (Phase 3). Return to the orchestrator: what you committed,
pushed, and merged; the exact worktree path + branch you recommend removing; or — if Steps 1–3 did
**not** all pass — what's still holding it (uncommitted/secret/stale work, unpushed commits, an
unmerged branch, a direct conflict) so it stays put. **Do not run `worktree remove` or `branch -d`
yourself** — surface the recommendation, don't execute the delete.

## Primary-merge conflict policy (same as preview sync)

**Each cleaner runs this itself, independently, for its own worktree** — conflict handling is not
centralized in the orchestrator. When merging a worktree branch into local `develop` (Step 3):

- **Try to resolve.** If the merge conflicts, attempt a correct combined resolution, then commit
  the merge. Never `-X theirs` / `reset` / discard to "win."
- **Irrelevant live WIP → ignore and proceed.** The primary checkout often has other people
  editing live. Uncommitted changes that are **not** about the same files/hunks as your worktree
  change are irrelevant: do **not** stash, discard, or rewrite them. Let git merge past them when
  it can do so without overwriting those paths. A dirty primary tree with unrelated WIP does not
  block the merge.
- **Direct conflict with your change → cancel and report.** Only when the primary's current changes
  (committed or uncommitted) **strictly and directly conflict** with your worktree change — same
  lines/files that can't coexist, or git refuses because the merge would overwrite *your*
  overlapping paths — do you `git -C <primary> merge --abort` (safe; restores the pre-merge state,
  live edits included), leave the primary as you found it, and **report + suggest**: keep/open a PR
  for the worktree branch, **or** wait until the conflicting live work is finished, then retry the
  merge. Leave that worktree/branch in place so the retry is one command.

## Phase 3 — Report, confirm, then delete (main thread only)

The cleaners have converged every finished worktree (committed, pushed, merged into local
`develop`) and **deleted nothing**. Deletion is a single gated step on the main thread — never
inside a cleaner:

1. **Present the whole plan in one report** — per repo: what each cleaner committed/merged, the
   exact set of worktrees + branches that passed Steps 1–3 and are safe to remove, and anything
   left in place with the reason.
2. **Ask for the user's explicit confirmation — and wait.** Name exactly what will be removed, e.g.
   *"Remove these 3 worktrees and delete these 3 merged branches? All are committed, pushed, and
   merged into `develop`."* No clear yes → stop here, delete nothing. The user may approve the whole
   set or only a subset — delete only what they name.
3. **Then delete only the confirmed set:**
```bash
git -C <repo> worktree remove <worktree-path>    # plain remove; refuses if dirty — don't force
git -C <repo> branch -d <branch>                 # -d only; deletes an already-merged branch, else refuses
git -C <repo> worktree prune                      # clear stale worktree admin entries
```
- **Only `-d`, never `-D`.** `-d` refusing is the safety net — if it errors, the branch isn't fully
  merged: leave it, flag it, don't escalate.
- Never remove a worktree/branch still holding unmerged or unpushed work — Steps 1–3 must have passed.
- **Hard precondition — the branch's commits must be in `origin/develop` (Step 2's decisive test).**
  Before removing any worktree/branch, confirm `git -C <repo> rev-list --count
  origin/<integration>..<branch-head>` is **`0`**. If it is `> 0`, deletion is **forbidden** even
  though `git branch -d` might succeed — `-d` checks reachability from the *local* branch you're on
  (which preview-sync may have satisfied), **not** whether the work reached `origin/develop`. A
  branch with a merged/closed PR and a non-zero count is orphaned-after-merge: leave it, and hand off
  a fresh-branch + new PR (Step 2). The only non-zero count that's allowed to survive untouched is one
  backed by an **OPEN** PR — and even then you keep the branch, you don't delete it.
- **Broken / locked worktrees.** Directory missing → `git -C <repo> worktree prune` clears the
  metadata; locked → report it rather than unlocking blindly.
- **Removing a worktree with an open PR is fine** once its commits are merged into local `develop`
  and pushed — the PR is backed by the remote branch, which stays put; only the local
  worktree/branch go away.

## Phase 4 — Reconcile local `develop` with `origin/develop` (main thread, per repo)

After the confirmed worktrees are removed, bring each in-scope repo's **local `develop` level with
the remote** — the merged PRs (this session's and any teammates') now live on `origin/develop`, and
the primary checkout should reflect the shipped state. This runs once per repo, on the main thread,
**only after** Phase 3's deletions. It obeys the same git-safety rule as everything else: **never
`reset` / `rebase` / force / discard** — a fast-forward when possible, a merge when not, and a report
when neither is safe.

Run it from the primary checkout, which Step 3 already left on `develop`:

```bash
git -C <primary> fetch origin <integration>                          # refresh origin/develop
git -C <primary> rev-parse --abbrev-ref HEAD                         # confirm it's on develop; if not, checkout develop (only if clean)
git -C <primary> rev-list --left-right --count develop...origin/<integration>
```

The `left-right` count is `<local-ahead> <remote-ahead>` — decide from it:

- **`0 0` — already level.** Nothing to do. Say "local `develop` already matches `origin/develop`."
- **`0 N` — remote ahead only (local strictly behind).** Fast-forward:
  ```bash
  git -C <primary> merge --ff-only origin/<integration>
  ```
  This is the common case after cleanup — pulls in every merged PR with no new merge commit.
- **`M 0` — local ahead only.** Local `develop` holds preview-sync commits (Step 3 merge-backs) that
  haven't reached the remote yet — **do not touch them, do not reset to the remote.** They ride to
  `origin/develop` when their PRs merge. Report "local `develop` is M commits ahead of the remote
  (preview commits awaiting their PRs) — left intact."
- **`M N` — diverged** (both have commits the other lacks). Integrate with a **merge, never a rebase
  or reset:**
  ```bash
  git -C <primary> merge origin/<integration> -m "Merge origin/<integration> into develop"
  ```
  Apply the **primary-merge conflict policy** above — resolve what you can, ignore unrelated live
  WIP, and on a direct clash `git -C <primary> merge --abort` (safe) and report, leaving local
  `develop` exactly as found.

**Guards:**
- **Never `--ff-only` past a divergence** — if `merge --ff-only` errors, the branches diverged; fall
  to the merge case, don't force it.
- **Dirty primary tree.** Unrelated live WIP doesn't block a fast-forward that only touches idle
  files; if the reconcile *would* overwrite an actively-edited file, it's refused before it starts —
  report it and leave `develop` as-is (same as the merge-refused case, never stash/clean to force it).
- **If production was promoted this session,** reconcile local `master`/`main` the same way (fetch →
  ff-only → merge-on-divergence), then finish back on `develop`.
- Skip the repo's reconcile when `gh`/remote is absent or the repo has no `origin/<integration>` —
  note it and move on; never block cleanup on a missing remote.

End on `develop` in every reconciled repo, and fold the result into the Phase-5 summary (per repo:
`develop` synced to `<sha>` / already current / ahead-and-left-intact / **diverge-merge done** /
**refused — flagged**).

## Remote-branch cleanup mode

Triggered when the user asks to tidy **remote** branches ("clean up remote branches", "prune remote
branches", "tidy the remotes", "dọn remote branch"). Same shape as the default mode — **survey
first, then fan out one subagent per remote branch** — but the target is `origin/*` and the deletion
is a *remote* one (`git push origin --delete`), so the safety bar is higher: a remote branch is
deleted **only when provably safe**, and everything else is *noted*, never force-removed.

### Phase 1 — Survey (main thread, read-only)
Per repo:
```bash
git -C <repo> fetch --prune origin                  # refresh remote refs; drop refs already gone
git -C <repo> branch -r                             # all remote branches
git -C <repo> branch -r --merged origin/develop     # remote branches fully in develop
gh -R <owner/repo> pr list --state all --json number,headRefName,state,mergedAt 2>/dev/null
```
Resolve `develop` and the **protected** branches (`develop`, `master`/`main`, plus any AGENTS.md
names). Build the candidate list of remote branches — **excluding protected ones**. (`gh`
unauthenticated → skip PR classification, judge from git alone.)

### Phase 2 — Fan out one "remote cleaner" per remote branch
Dispatch one subagent per candidate remote branch, in parallel — branch checks are read-only, so
this fans out fully across branches *and* repos. Each remote cleaner runs:

**Check 1 — Fully merged into `develop`, nothing pushed since?** The single decisive test:
```bash
git -C <repo> rev-list --count origin/develop..origin/<branch>   # commits on the branch NOT in develop
```
- **`0` → SAFE TO DELETE.** Every commit is already in `develop`; nothing on the branch is lost —
  this also proves "no push since the merge," since any post-merge commit would show up here.
- **`> 0` → NOT safe.** The branch carries commits `develop` lacks — never merged, or pushed after
  its PR merged (a new change set). Do **not** delete → Check 2.

**Check 2 — For a branch with unmerged commits: is that code good, or stale?** Before recommending a
merge-back, apply the worktree Step 1 staleness gate to `origin/develop..origin/<branch>`: far
behind `develop` (targets old code)? already done elsewhere (duplicate)? half-applied / broken?
- **Good, wanted work →** note **"needs merging back into `develop` (or a PR) before it can be
  deleted"**; if the merge into local `develop` is clean and safe, land it (primary-merge conflict
  policy above — each cleaner handles its own conflicts), which makes the branch safe on a re-check;
  otherwise suggest a PR. Do not delete yet.
- **Stale / superseded / broken →** note it **stale — don't merge, don't delete**; recommend a PR
  for a human call or abandoning it. Never auto-delete unmerged work, however stale it looks.

**Guards (every branch):**
- **Never delete a protected branch** (`develop`, `master`/`main`, AGENTS.md-named).
- **Never delete a branch with an OPEN PR** — deleting its head orphans the PR. Merged/closed PR is
  fine.
- **Never force.** Deletion is `git push origin --delete <branch>` only, for a Check-1-safe branch.
  Also drop the now-merged local tracking branch with `git -C <repo> branch -d <branch>` (never `-D`).

### Act — report, get explicit confirmation, then delete only the safe set
Deleting a remote branch is outward-facing and not cheaply reversible, so **present the plan and
wait for the user's explicit confirmation before deleting anything** — list every branch as
**safe-to-delete** / **needs-merge-or-PR-first** / **stale** / **protected-or-open-PR-skipped**,
then, once the user confirms, delete only the safe-to-delete set they approve:
```bash
git -C <repo> push origin --delete <branch>    # ONLY when rev-list count was 0; never --force
git -C <repo> branch -d <branch>               # drop the local tracker too, if present and merged
```

### Report (remote mode)
Per repo, three lists: **Deleted** (safe, fully-merged remotes removed), **Needs merge/PR before
delete** (unmerged-but-good branches, each with the suggested action), and **Left as-is** (stale,
protected, or open-PR branches, each with a one-line reason). Nothing is deleted that had a single
commit not already in `develop`.

## Redundant-file & image cleanup mode

Triggered when the user asks to tidy **files or assets** rather than branches — "clean up redundant
files", "remove unused images", "delete orphaned assets", "dọn file thừa / ảnh thừa", or a plain
"clean up" explicitly scoped to files. Same spine as every mode: **survey → report → confirm → act;
never delete first, never delete unasked.** Deleted files have **no reflog** — recovery is far
harder than for a branch — so the confirmation bar is at least as high, and untracked deletions are
irreversible once done.

**Product-asset rule first (AGENTS.md).** In many repos the images and data files **are the
product**, not junk — e.g. this project's cropped question images and `source_assets` ground-truth
under `books/` are tracked deliverables. **Never treat a product asset as redundant.** A file
becomes a deletion candidate only when it lands cleanly in one of the three provable buckets below;
anything else stays, and when unsure you **flag, never delete**.

### Phase 1 — Survey candidates (read-only), sort into three buckets
Per repo, gather candidates — deleting nothing during the survey:

1. **Junk / scratch artifacts** — same tells as `/ship`'s junk check: scratch captures
   (`review-*.png`, `*-before*.png`, screenshots dropped at the repo root), `*.log`, HAR/trace dumps
   (`*.har`, `trace.zip`), `.DS_Store`, tool scratch dirs (`.playwright-mcp/`, `.harness-backup/`,
   `tmp/`, `scratch/`), build output (`dist/`, `__pycache__/`, `node_modules/`). **Judge by intent,
   not extension** — a `.png` under `src/assets/` or `books/…` is a real asset; twenty `review-*.png`
   at the repo root are scratch.
   ```bash
   git -C <repo> ls-files --others --exclude-standard    # untracked, not gitignored — where scratch hides
   git -C <repo> status --porcelain --ignored            # also shows ignored scratch dirs
   ```
2. **Orphaned / unreferenced assets** — a file (especially an image or data file) that **nothing
   references any more**, because the record/manifest/code that owned it was removed. **Prove it
   before flagging** — search every plausible reference (basename, stem, relative path):
   ```bash
   git -C <repo> grep -lF "<basename>"                    # any code/JSON/manifest still naming it?
   ```
   Zero hits → candidate orphan. **A single hit clears it — a referenced asset is never redundant.**
   Manifests, dynamically-built paths (`f"…/{id}.png"`), and tests all count as references: when a
   name is assembled at runtime, treat the asset as referenced unless you can prove its owning record
   is gone. Orphans are the highest-risk bucket — bias toward flagging for a human call.
3. **Exact duplicates** — byte-identical files where one copy is redundant:
   ```bash
   git -C <repo> ls-files -z | xargs -0 shasum | sort | uniq -w40 -D   # tracked dupes by hash
   ```
   Keep the canonical one (the referenced path / the one under the conventional dir); the extra copy
   is the candidate.

### Guards — what is never a candidate
- A git-tracked file with **≥1 reference**; any file with **uncommitted edits** (someone's WIP);
  **product assets** under the project's asset/data dirs per AGENTS.md (e.g. `books/…`).
- **Untracked ≠ delete-on-sight.** Untracked scratch is the safest to remove, but a fresh untracked
  file may be live WIP not yet `add`-ed — if it isn't an obvious scratch tell, flag it, don't sweep it.
- **Gitignored files are usually intentional local state** (`books_verified/`, `.env`, caches) — don't
  propose deleting them unless the user names them explicitly.
- Never `clean -f` / `reset` / `stash` to bulk-remove. Deletion is **per-file and confirmed**, never
  a blanket sweep. Size alone never makes a file junk.

### Report → confirm → delete
1. **Report all three buckets** per repo — each candidate with its bucket + one-line why (scratch
   tell / zero references found / duplicate of `<path>`), grouped with counts. Show exactly what would
   be deleted.
2. **Wait for explicit confirmation**, naming the set (the user may approve a subset). No clear yes →
   delete nothing.
3. **Delete only the confirmed set:** `git -C <repo> rm <path>` for tracked files, plain `rm <path>`
   for untracked; add recurring scratch dirs to `.gitignore` so they don't return. Report deleted vs
   left-and-why, per repo.

## Phase 5 — Summary, report per repo

End with a compact per-repo table: for each worktree/branch — commit status, push status,
merged-into-`develop` status, PR suggestion (if any), and whether it was removed. Then a
**"Not tidied"** block listing anything left in place and why (uncommitted secret, unmerged work,
a direct conflict awaiting a PR/wait-and-retry, a new change set needing a fresh PR). Nothing is
silently dropped: if a worktree survived, the report says exactly what it's still holding.
