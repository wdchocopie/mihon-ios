---
name: parallel-execution
description: "Execute an approved plan by fanning work across parallel builder subagents — aiming for at least 4 working concurrently — and, once the whole thing is built, verifying it through ONE consolidated /test run that enumerates a TEST_MATRIX and fans testers across every flow at once, bouncing failures back to the builder that owns the code. First works out a conflict-free distribution of the tasks (disjoint file ownership, dependency waves), THEN spins up the agents to execute them. Triggers on 'execute the plan', 'build this', 'implement the spec', 'let's build it', 'go ahead and make it', right after a plan is approved with multiple independent pieces, or any request to parallelize the build / fan out agents. If a plan genuinely can't justify 4 conflict-free lanes, fanning out isn't worth it — hand back to senior-engineer to build it solo. NOT for QAing an already-built feature (use the test skill), one mechanical change across many files (use codebase-wide-change), or a small single-file edit."
version: 2.5.0
---

# Parallel Plan Execution

The senior-engineer family's engine for **carrying out an approved plan**. The premise: a
plan built one piece at a time in a single context is slow and error-prone. A senior engineer
instead **decomposes the plan, parallelizes the work across specialists, and — once the whole
thing is built — verifies it through a single consolidated `/test` run.** That run enumerates the
full feature, writes the cases into `TEST_MATRIX.md`, and fans parallel testers across every flow
at once, so coverage is exhaustive and the cross-part seams get exercised together rather than in
isolation. When a flow fails, it routes straight back to the builder that owns that code — reached
via `SendMessage`, so its original context is intact and the fix is cheap.

**Default to parallel. Always.** Your job is not to *decide whether* to parallelize — it's to
*find the seams that let you*. Most work that looks sequential isn't: it's coupled by a shared
interface you can pin up front (see Step 2), and once pinned, the parts run concurrently
against that contract. Treat "this has to be sequential" as a claim you must actively try to
*disprove* before you accept it — not a default you fall back to. Genuinely unparallelizable
plans exist, but they are the rare exception, and you only conclude it after you've looked for
the seams and found none.

**Two phases, in order: distribute, *then* dispatch.** Senior-engineer hands you the *tasks* —
the deliverables to build. Your first job is to work out a **conflict-free distribution** of
those tasks: disjoint file ownership and dependency waves (Steps 1–2), so that no two agents
ever write the same file. Only once that distribution is provably conflict-free do you **spin
up the agents** to execute it (Step 3). Thinking the distribution through before dispatching is
exactly what turns a fan-out from a race into a clean parallel build — so never skip straight
to spawning agents.

**The floor is four.** When you fan out, fan out to **at least four agents working in
parallel** — that's the target whenever you parallelize at all, not a ceiling. The whole point
of this skill is *real* concurrency; stopping at two or three builders almost always means you
gave up hunting for seams too early (Step 0.3). Most features have four-plus conflict-free
lanes once you actually look: backend, frontend, shared types/schema, tests, docs, separate
endpoints or screens, the wiring/glue. Go find them before you settle for fewer.

**The one escape — and where it goes.** If, after genuinely working the decomposition, you
*cannot* find four conflict-free lanes worth handing off — the task is small enough that
splitting it four ways would manufacture busywork instead of real parallel work — then it is
**not worth fanning out at all.** Do **not** fall back to a half-hearted two-agent split.
Instead, **hand control back to `senior-engineer` to build the feature solo** in its own
context. The choice is deliberately binary: either a real ≥4 fan-out, or a focused solo build —
never a token gesture at parallelism. Catching yourself inventing a flimsy fourth lane just to
clear the bar *is* the signal that solo is the right call; say so and hand back.

You are the **orchestrator**. You stay in the main loop, keep the whole picture, dispatch
builders, then — once the whole build has landed — route the verification through one consolidated
`Skill(test)` run, run the feedback loop, and report back. You do not write the feature code yourself — your job is decomposition, coordination, and
judgment.

## When this is worth it (and when it isn't)

The bias is **strongly toward fanning out**. If a plan has more than one deliverable, your
starting assumption is that it parallelizes — and you go looking for how, rather than asking
whether. Coordination overhead is real but small next to the time a single-context serial
build costs.

**Use it whenever:**
- There's a **plan or spec with multiple parts** to build. Even if the parts *look* dependent,
  go to Step 2 and try to pin a contract that decouples them before concluding otherwise.
- The user says "execute/build/implement this", or a plan was just approved.
- The work spans several features, layers, or modules — backend + frontend, multiple
  endpoints, multiple screens, schema + code. These almost always have parallelizable seams.

**The only genuine reasons NOT to fan out to ≥4** — and you should be able to name which one
applies. In each case the fallback is *not* a smaller fan-out; it's the named alternative:
- It's a literal **single-file or one-function change**, or so small that four lanes would be
  busywork — there's nothing real to decompose → **hand back to `senior-engineer` to build it solo.**
- The task is pure QA of something already built → **`test`** (`/test`).
- The task is one mechanical edit repeated across many files → **`codebase-wide-change`**.
- You've **actively tried** to find seams (Steps 1–2) and every part has a hard data
  dependency on another part's *runtime behavior* that no pinned contract can remove. This is
  rare — most "dependencies" are interface dependencies, which contracts dissolve. If the work
  is genuinely a serial chain too small to fan out → **solo via `senior-engineer`.**

Do **not** treat "the parts feel coupled," "it's simpler to do in order," or "I'm not sure how
to split it" as reasons to drop below the floor. Those are signals to work harder at
decomposition, not to give up on it. And do not treat them as license for a quiet 2–3 agent
compromise either — the choice is a real ≥4 fan-out or a solo build, nothing in between. If
after a genuine attempt you don't fan out, **say explicitly which reason above applies** —
don't silently default to it.

---

## The workflow

### Step 0 — Ground yourself in the plan and the project

You can't parallelize what you don't understand. Before dividing anything:

1. **Pin down the plan.** If a plan/spec already exists (a plan-mode output, a doc, a
   sprint), read it in full. If the user gave a loose ask ("build the settings page"),
   restate the plan as a short ordered list of concrete deliverables and confirm it. Don't
   fan out against a vague target.
2. **Learn the project's ground truth** — `CLAUDE.md` / `AGENTS.md` / `README`, the stack
   and layout (where backend, frontend, tests, types live), how to run and test it (dev
   command, ports, type-check/lint/test commands), and the conventions. The builders and
   testers inherit none of your context, so you must gather what they'll need to be handed.
3. **Hunt for the parallelizable seams.** Don't ask "is this parallelizable?" — ask "*where*
   are the seams?" Look for them along every axis: by layer (backend / frontend / data /
   docs), by feature or route, by module, by file boundary. A plan that reads as "one tangled
   change" is usually one you haven't sliced yet — the tangle is almost always a shared
   interface, which Step 2 pins so the pieces come apart. Only after genuinely looking and
   finding the work truly inseparable do you build it directly — and then you name why.

### Step 1 — Decompose into parts and order them into waves

Carve the plan into **coherent parts**, each one a deliverable a single builder can own end
to end (e.g. "the orders API endpoint + service", "the settings page UI", "the DB
migration + shared types"). Then order them by dependency — this is the crux:

- **Foundations first.** Shared types, schema/migrations, API contracts, and core utilities
  that other parts import must land *before* their dependents. Put them in an early wave,
  usually built by **one** builder to avoid races on shared files.
- **Independent parts in parallel.** Parts that don't touch each other's files and don't
  depend on each other's not-yet-built code go in the **same wave** and run concurrently.
- **Integration/glue last.** Wiring, end-to-end flows, and anything that stitches parts
  together goes in a final wave once its inputs exist.

Write down the **wave plan**: which parts are in each wave, what each part delivers, and its
dependencies. A wave is just "the set of parts that can safely run at the same time."

**Check the count against the floor.** Once the parts are carved, count the agents your widest
wave will run concurrently. If it's under four, that's a prompt to look again, not a verdict:
can a fat part split along file boundaries into two lanes? Does the plan have tests or docs
that deserve their own builder? Are there separate endpoints/screens you lumped together? Pull
those apart and you'll usually clear four. If you *still* can't — and forcing a fourth lane
would only invent busywork — then this plan isn't worth fanning out: stop here and hand it back
to `senior-engineer` to build solo (see "The one escape" above). Reaching four real lanes is
the goal; faking the fourth is the tell that solo is correct.

> Keep waves honest — but keep them *wide*. Before you push a part into a later wave for
> "depending on" an earlier one, ask what it actually depends on. If it's an **interface**
> (a type, a function signature, an API shape, a CSS class name), that's not a real wave
> barrier — **you pin that interface yourself in Step 2** and both parts build to it
> concurrently. A dependency only forces sequencing when a part needs another part's
> *running code or generated artifact* to exist first (a migration applied before a seed runs,
> a built library before something imports its compiled output). Push interface-coupled parts
> into the **same** wave with a pinned contract; reserve later waves for true runtime
> dependencies. The failure mode to avoid is not "too parallel" — it's serializing work that a
> five-minute contract decision would have let run side by side.

### Step 2 — Assign disjoint file ownership

Before dispatching, decide **which files each builder owns**. The rule that prevents the
worst class of bugs: **no two concurrent builders write the same file.** If two parts must
touch one file (a shared router, a barrel export, a config), either:
- put them in **different waves** (one after the other), or
- give **one builder both parts**, or
- have the orchestrator make that one shared edit itself after the builders return.

**Pin the shared contract before fanning out.** When parts in the same wave share an
interface — a type/field shape, an API request/response, CSS class names a renderer and a
stylesheet must agree on — decide that contract *yourself* up front and put it verbatim in
**every** affected builder's brief. This is what lets parts in different files run
concurrently without one guessing at the other's interface: they don't coordinate at
runtime, they both build to the contract you handed them. (In single-file apps where the
coupled work can't be split across files at all, that's your signal to give one builder the
whole coupled part rather than to parallelize it.)

This also protects the user's working tree: builders only create/modify files in their lane,
and **never revert or overwrite changes they didn't make** — yours, the user's, or another
builder's. (See `references/` of the family and the project's own rules; foreign changes are
off-limits.)

### Step 2.5 — Hand down shared context; don't make each builder re-derive it

By now you've explored the codebase and pinned the contract — which means the expensive
understanding already lives in *your* context. The trap is letting it stay there: if every
builder has to open the same 60-KB source file, re-read the same spec, and re-grep the same
sample data to reconstruct what you already know, you pay that reading cost **once per agent**.
Five builders independently re-deriving the same shared context is the single biggest avoidable
token sink in a fan-out — and it's pure waste, because you already did that reading in Step 0.

So before dispatching, split the context into two layers and treat them differently:

- **Shared-once** — facts *every* builder needs identically: the pinned contract, the canonical
  code they're all mirroring, the class/field/enum inventory, the base schema, the sample-data
  quirks you uncovered. Distill this **yourself, once**, into a compact **context pack** — a
  short artifact (e.g. `.claude/plans/<feature>-context.md`) — and point every brief at that one
  file instead of at the raw sources. Better still, when a region is small and many builders all
  need it, **paste the actual snippet into the pack** rather than citing `bigfile.ts:120-140`: a
  line citation still forces a file-open and a scan, the pasted lines don't.
  **Accuracy safeguard — paste verbatim for complex or edge-case-heavy logic; prose-summarize
  only the simple parts.** A distilled pack is only as faithful as what you put in it: prose
  reliably carries the *structure* a builder needs (tested — even a summary-only pack got the
  hard rules right and the builder inferred the rest), but it silently drops fine-grained details
  it doesn't spell out (an exact pixel value, a placeholder string, one branch of an edge case).
  So for anything intricate — a canonical render function, a state machine, a non-obvious field
  mapping, a rule with many interacting cases — paste the real code/spec verbatim rather than
  describing it, and let purely cosmetic details live in shared code (a stylesheet, a constants
  file) where they can't be paraphrased away. The drift a pack introduces is then cosmetic, not
  logical — the kind a normal visual/test pass catches, not the kind that ships a wrong feature.
- **Per-agent** — what only that one builder reads: its own target files and the slice of sample
  data for its part. Leave this in the lane; it isn't duplicated across agents, so it isn't waste.

The exploration from Step 0 is the raw material for the pack — if you ran `deep-exploration`, its
returned findings are already most of it, so capture them into the pack instead of letting them
evaporate back into your context alone. If the shared material is too large to distill inline,
spawn **one** "librarian" builder to read the heavy sources and emit the tight reference, then
feed *its* output to the rest of the wave — one read of the big files instead of N.

This front-loads a little cost onto you (distilling, pasting) to save it across the whole wave,
so it pays off exactly when the fan-out is **wide over shared source material** (≥3 builders
mirroring the same canon) and isn't worth the ceremony for two agents editing small, unrelated
files. It composes with Step 2: the context pack is simply where the contract you pinned — plus
the rest of the shared canon — gets written down once, for everyone. (One thing it does *not*
buy you: a shared prompt-cache across siblings. Each subagent is a fresh context with its own
cache, so the pack, not caching, is the lever you actually control.)

### Step 3 — Dispatch the wave's builders in parallel

For each wave, spawn all its builders **in a single message** (multiple Agent calls at once)
so they run concurrently. Pick the agent type that fits each part:
- **`backend-builder`** — APIs, services, business logic, data layer, migrations, seeds.
- **`frontend-builder`** — pages, components, hooks, state, styling, localized UI.
- **`documenter`** — docs/changelog parts, if the plan includes them.
- **`general-purpose`** — anything that doesn't fit the above.

Give each builder a **self-contained brief** — it has none of your context. Read
`.claude/skills/parallel-execution/agents/builder-brief.md` and follow it; at minimum the
brief carries the part's scope, its **file ownership** (and explicit out-of-scope files),
the relevant plan/spec text, a pointer to the **Step 2.5 context pack** (so the builder reads
the distilled shared context instead of re-deriving it from raw sources), project conventions
and run/test commands from Step 0, the **acceptance criteria** the part must meet, and the
return format. The test of a good brief: the builder's **first tool call opens a file in its
lane** — if its first move would be `ls`/`grep` to orient itself, or opening a file outside
its lane just to understand the task, the brief is missing context you already hold; paste it
in (or into the pack) before dispatching, don't let N builders re-explore what you read once.
Name each agent so you can
reach it later via `SendMessage` for the fix loop — that preserves its context instead of
re-explaining from scratch.

Wait for a wave to finish **building** before starting the next wave that depends on it —
dependencies are about built code existing, not about it being tested yet (testing is deferred to
one consolidated run after *all* waves land, Step 4). Independent later-wave parts can start as soon
as their own build dependencies are satisfied — you don't have to drain every wave to the last agent
if nothing downstream needs it.

### Step 3.5 — Checkpoint each wave into git; open the draft PR on the first commit

Don't hold the whole feature uncommitted until the end. **When a wave's builders all return,
commit their work in the worktree and push it** — so the PR grows one wave at a time and anyone
watching sees the feature take shape instead of waiting for a single end-of-build drop.

- **First wave lands → publish.** After the first wave is committed, push the `ship/<slug>` branch
  and open a **draft** PR into `develop` (the mechanics — `git push -u` then `gh pr create --draft`
  — live in `senior-engineer`'s "Implement in a worktree off `develop`" lifecycle). Do this once;
  every later wave's commit rides the same open PR.
- **Each later wave → commit and push on top.** One commit per wave (subject = the wave's parts),
  pushed as soon as the wave is built, so the open PR keeps growing in view.
- The PR stays **draft** through the build. It's marked ready only after Step 4's `/test` passes —
  that's `senior-engineer`'s close, not something you flip while parts are still failing.

This is a build-visibility checkpoint, **not** a test gate: waves are committed as they *build*;
verification is still the single consolidated `/test` run in Step 4 after every wave has landed.

### Step 4 — After the whole build lands, design the cases with `/testcase-gen`, then verify through ONE consolidated `/test` run

**First design the cases.** Before the `/test` run, invoke `Skill(testcase-gen)` **once** over the
whole feature to turn its spec basis (Features + Business Logic) into atomic **test cases**,
**scenarios**, and an updated **RTM** — the written, traceable case list `/test` then executes. Hand
it the same package you assembled below (parts, acceptance criteria, the spec/modules touched) so it
doesn't re-hunt the docs. Skip this only when the feature has **no spec basis** to derive cases from
(an un-specced change) — then go straight to the `/test` run. The `/test` run below draws the flows
it enumerates into `TEST_MATRIX.md` from the scenarios this step produced, so design and execution
stay in lockstep.

Then the verification. This is the differentiator — and the **order** is the point: you do **not** test part-by-part as
builders land. You let the *entire* build finish first — all waves complete, every part returned —
and **only then hand the whole feature to a single `Skill(test)` run.** Per-part testing fragments
the picture: each part gets a shallow, bounded check that can't see the flows crossing two parts.
`/test` is built for the opposite — take a whole changeset and enumerate it exhaustively. It thinks
through *every* case, writes them into `TEST_MATRIX.md`, then fans out parallel testers across
**both tracks at once** — UI flows in real browsers, backend/API flows straight against the running
services — all running simultaneously. One consolidated run gives deeper, matrix-backed coverage
than N narrow per-part runs ever could, exercises the cross-part seams together, and keeps testing
owned in one place instead of this skill reinventing a shallower version. **You do not hand-roll
tester agents for any of it.**

**Assemble the consolidated context, then hand off once — don't make `/test` re-derive what you
already hold.** Since Step 0 you've held the whole picture, so package it rather than letting `/test`
rediscover the feature from scratch:
- the **list of parts that were built** and what each delivers;
- every part's **acceptance criteria** (what PASS/FAIL is measured against);
- the **run/reach details** — dev command, ports, API base, seed/auth credentials, type-check/test commands;
- the **file-ownership map** from Step 2, so a failing flow can be traced back to the builder who owns that code.

Read `.claude/skills/parallel-execution/agents/tester-brief.md` for exactly how to package this.
Invoke `Skill(test)` **once**, scoped to *the feature you just built* (so it stays bounded to your
change instead of ballooning into a full-app pass), and let it run its own enumerate → document →
fan-out procedure. It returns a **per-flow verdict** across the whole feature; collapse that into a
per-part picture so you know who fixes what:

- **PASS** — every acceptance criterion met across the feature's flows; note what was checked.
- **FAIL** — for each failing flow: a one-line description, severity (blocker / minor), steps to
  reproduce, and the suspected `file:line` — which, via your ownership map, names the builder who owns it.

The testers `/test` spawns **read source and drive the live app/API**; they **do not write production
code and never revert anyone's changes** — the builder fixes (Step 5), the verification only reports.

> **The one fallback to a raw tester.** If Playwright servers aren't set up *and* the feature is
> purely UI with no API surface, `/test` will say so (its UI track needs a browser). In that narrow
> case, either offer to install Playwright (so `/test` can run its UI track) or, for a quick inline
> check, fall back to a single `tester` agent per `tester-brief.md`. Backend/API surfaces never need
> this — `/test`'s backend track runs without any browser.

### Step 5 — Fix loop: route each failure back to the builder that owns it

When the consolidated `/test` run returns FAIL on a flow, **send the findings to the builder that
owns the implicated part** via `SendMessage` (not a fresh agent — the original builder still holds
the context for why the code is the way it is). Your Step 2 file-ownership map plus `/test`'s
suspected `file:line` tell you which builder that is; when a failure spans two parts, send it to
both with the seam called out. Hand over `/test`'s exact findings: the repro, the suspected
location, the severity. The builders fix, then **re-run `/test`** — scoped to the flows that failed
(and any they touch), not the whole matrix again.

Cap this at **two fix rounds.** If a flow still fails after two rounds, stop looping and **surface
it to the human as an open blocker** with everything learned — what's wrong, what was tried, where
it likely lives. Burning more rounds usually means the plan or a dependency is wrong, which is a
human call, not a retry.

Only consider the build **done** when `/test` has confirmed every flow PASS (or the user has
explicitly accepted a known-incomplete part).

### Step 6 — Integration is already inside the consolidated run

Because Step 4 hands `/test` the *whole* feature at once rather than part-by-part, the cross-part
end-to-end flows — a UI that calls the API you just built, a flow that spans modules — are already
in the case list `/test` enumerates and exercises in the same fan-out. There's no separate
integration pass to bolt on here: the seam bugs a per-part scheme would have missed are caught
because the testers see the *assembled* feature, not isolated pieces. (If the user wants exhaustive
end-to-end QA of the whole app — beyond this feature — that's `/test all`'s job; point them there.)

### Step 7 — Synthesize and hand off for human QA

You orchestrated; now give the human a clear picture. Report:

```markdown
# Plan Execution: <plan name>

## Summary
<1–2 lines: what was built, how many parts, how many waves, overall state>

## Parts
| Part | Builder | Wave | Test verdict | Fix rounds | Notes |
|------|---------|------|--------------|-----------|-------|
| Orders API | backend-builder | 1 | ✅ PASS | 0 | |
| Settings UI | frontend-builder | 2 | ✅ PASS | 1 | fixed validation gap |
| Export flow | backend-builder | 2 | 🚫 OPEN | 2 | still failing — see below |

## Open blockers (need a human decision)
- <part> — <what's wrong, what was tried, suspected location>

## Verified vs. needs human QA
- Verified by testers: <list>
- Recommended human QA before shipping: <list — anything testers couldn't fully exercise>

## Files changed
<by part / builder, so the human can review the diff>
```

Output the report in chat. Don't write it to a file unless asked.

---

## After every run — suggest next steps

End with a brief **"What you can do next:"** (2–4 items): resolve the top open blocker (with
its suspected location), review the diffs for the passed parts, run the project's full test
suite, run `/test all` for exhaustive end-to-end QA, or — since the PR is already open and grew
wave by wave — mark it ready and merge it (`/ship merge`) if everything passed cleanly. Keep it to
a bulleted list — the goal is momentum and the clear
highest-impact next action.

---

## Guardrails (senior-engineer judgment, always on)

- **Parallelize by default; the floor is four.** When you fan out, fan out to **at least four
  agents in parallel** — that's the target, not the cap. "It felt easier in order" is not a
  reason to go under; a hard runtime dependency that no pinned contract removes might be. The
  bias is toward fanning out — when in doubt, find the seam and split.
- **The decision is binary: a real ≥4 fan-out, or a solo build — never 2–3.** If you genuinely
  can't find four conflict-free lanes worth handing off, don't settle for a half-hearted
  two-agent split; **hand back to `senior-engineer` to build it solo.** Manufacturing a flimsy
  fourth lane to clear the bar is itself the signal that solo is right.
- **Right-size above the floor — don't *over*-thrash either.** The hard cap is correctness: no
  two concurrent builders on one file. Above four, match the agent count to the plan's real
  independent parts; don't split a coherent part eight ways onto shared files just to inflate
  the number. Most plans are under-parallelized, not over — but the floor is about *real* lanes,
  never fabricated ones.
- **Context flows downhill — no agent re-explores what you already know.** You (and
  `deep-exploration`) paid the reading cost once; every dispatch inherits it via the brief and
  the Step 2.5 context pack. A builder grepping the repo to orient, or a `/test` run
  rediscovering how to start the app, means the handoff dropped context you held — fix the
  brief/pack, not the agent.
- **Never let agents revert foreign changes.** Disjoint file ownership, and an explicit rule
  in every brief: create/modify only your lane; never undo edits you didn't make. The working
  tree may hold the user's own work or another agent's in-progress changes.
- **Push back on a bad *plan*, not on parallelism.** If the plan itself is half-baked or
  underspecified, say so and fix the plan — that's the senior move. But "the parts seem
  coupled" is not grounds to push back; it's grounds to pin a contract and split them. Exhaust
  decomposition before you ever conclude a multi-part plan must be built serially.
- **The build isn't done until `/test` confirms it.** "The builders said it's done" is a claim,
  not a verification. The test phase exists precisely because builders are optimistic — and after
  every part has landed, the *whole feature* goes through one consolidated `Skill(test)` run, not
  raw tester agents you spin up yourself.
- **If a builder fails/times out, or a `/test` run can't complete**, report that part as
  INCOMPLETE with the error; don't silently drop it from the plan.

---

## Relationship to the senior-engineer family

- The **`senior-engineer`** persona routes here when the user moves from planning to building. It
  owns the git/PR lifecycle around this build — cutting the `ship/<slug>` worktree, opening the
  **draft PR on the first commit**, and the merge-back — while you commit each wave onto that branch
  (Step 3.5) so the PR grows in view instead of landing all at once at the end.
- **`deep-exploration`** is the read-only counterpart — understand a codebase; this one
  changes it. Run exploration first if the plan touches code you don't yet understand.
- **`test`** (`/test`) is the verification engine this skill's consolidated test phase hands off
  to (Step 4) — *once the whole build has landed*, the entire feature goes through one `/test` run
  that enumerates a TEST_MATRIX and fans out parallel UI + backend/API testers across every flow at
  once. This skill does **not** spin up raw `tester` agents itself. For exhaustive end-to-end QA of
  the whole app (beyond this feature), hand off to `/test all`.
- **`codebase-wide-change`** owns the *one-change-everywhere* refactor; reach for it instead
  when the "plan" is really a single mechanical edit repeated across files.
