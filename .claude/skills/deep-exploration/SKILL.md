---
name: deep-exploration
description: "Divide-and-conquer investigation of an unfamiliar or large codebase before acting. Triggers on 'investigate thoroughly', 'dig into the codebase', 'understand how X works before answering', 'trace this end to end', 'map out the system', or any hard code question you shouldn't answer from a quick glance — and as the exploration engine behind a codebase review or codebase-wide change spanning more than one feature/module. Maps the repo bird's-eye, splits it into sections (three at minimum — the floor — scaling to 8–10+ for audits/monorepos), dispatches one read-only Explore subagent per section in parallel, then synthesizes their findings into one mental model. NOT for a single known file, a one-line lookup, or a quick question you can answer directly — that wastes subagents; reach for it only when breadth or depth genuinely warrants the fan-out."
version: 1.3.0
---

# Deep Codebase Exploration

A divide-and-conquer method for building a **thorough, trustworthy mental model** of a
codebase before you act. The premise: one agent reading files top-to-bottom misses things
and runs out of context on a large repo. A senior engineer instead **scopes the whole
thing first, divides it into sections, and sends a specialist into each section in
parallel** — then stitches the findings back together.

## When this is worth it (and when it isn't)

This approach spends multiple subagents, so use it deliberately.

**Use it when:**
- The task needs deep understanding of unfamiliar code (you can't answer from memory or a glance).
- The work touches **more than one feature/module** (a review, a cross-cutting change, a "how does the whole flow work" question).
- The user explicitly asks you to **investigate thoroughly before answering**.
- You're the exploration phase of a **codebase review** or a **codebase-wide change**.

**Don't use it when:**
- You already know the one file/function involved — just read it.
- It's a quick factual lookup or a single-file edit.
- The repo is tiny enough that one pass covers it.

If you're unsure, ask yourself: *would three specialists reading in parallel actually find
more than I would alone here?* If no, skip the fan-out and read directly.

---

## The workflow

### Step 1 — Bird's-eye overview (you do this yourself, fast)

Before dividing anything, get oriented. The goal is a map, not mastery:

1. **Read the project's entry/config files** — `package.json`, `pubspec.yaml`,
   `requirements.txt`, `go.mod`, `Cargo.toml`, `README`, `CLAUDE.md`, and any
   architecture docs. Identify the stack, frameworks, and how the app is built/run.
2. **Survey the directory structure** — use Glob/`ls`/`tree`-style listing to see the
   top-level layout. Identify the major areas: entry points, routing, state, data layer,
   services, UI, config/infra, tests.
3. **Sketch the seams** — note where the natural boundaries are. These boundaries become
   your sections in the next step.

This pass has two outputs, so capture both: the **section boundaries** (with a first read
on how many sections the task warrants — see Step 2's scaling), and the **facts every brief
will inherit** — the stack/framework, how the app is built/run, and the entry files and key
paths you spotted (as `path` or `path:line`). Anthropic's core finding on orchestration is
that delegation quality lives in the briefs; this map is where the briefs' raw material
comes from, so don't let it evaporate into a vague impression.

Keep this pass shallow and quick. You are looking for the shape of the system, not the
details — the subagents get the details.

### Step 2 — Divide the codebase into sections

Carve the repo into **coherent, mostly-independent sections** sized so one Explore agent
can investigate each thoroughly without drowning. Good seams to cut along:

- **By layer** — presentation / domain / data / infra
- **By feature or module** — auth, billing, inventory, sync, …
- **By concern** — routing, state management, error handling, testing, build/CI

Aim for sections that don't overlap much and that together cover everything that matters
to the task. **Always carve at least three sections — three is the floor, by design.**
This skill is deliberately all-or-nothing: either the task warrants a real fan-out — three
or more independent vantage points, so Step 4's cross-section synthesis has seams to
expose — or it doesn't warrant a fan-out at all, in which case don't run this skill (see
*When this is worth it*). There is no two-agent middle: a 2-agent run is the under-fan-out
drift this floor exists to resist, not a judgment call available to you. Scale up from
the floor:

- **3 (the floor)** — a typical multi-module task: one feature traced end to end, a
  focused cross-cutting question, a mid-size repo.
- **5–8** — a whole-repo review or audit, a monorepo, or a change that touches most layers.
- **8–10+** — a large monorepo or an exhaustive audit where every section is still a full
  brief's worth of code.

If the code is small but the questions are rich — or the prompt names only two targets —
hit the floor by cutting briefs **by lens over the same code** rather than by directory:
e.g. one agent on data/control flow, one on error handling and edge cases, one on tests
and contracts. Overlapping scopes viewed from different angles are fine; three independent
readings still surface more than one pass would. Give the lens-cut brief the same care as
the others — concrete questions, named starting files — so it earns its agent instead of
padding a quota. What you should *not* do is cram two unrelated concerns into one agent.
And if you genuinely can't write three briefs worth an agent even by lens, that's the
signal this task never needed the fan-out — fall back to reading directly rather than
running a hollow three.

Write down the section list and, for each, a **focused brief**: what that agent should
find out, which directories to look in, and which specific questions it must answer.

### Step 3 — Dispatch one Explore subagent per section (in parallel)

Spawn the Explore subagents — **three at minimum**, one per section Step 2 carved — **in a
single turn** (multiple tool calls in one message) so they run concurrently. Use the **`Explore`** agent type — it's read-only and built for
broad fan-out search; it reads excerpts to locate and explain code rather than dumping
whole files.

Give each agent a **specific, self-contained brief** — it has none of your context, and the
cardinal rule is: **everything you already know that the agent would otherwise have to
rediscover goes into the brief.** You just did the bird's-eye pass; the user may have given
constraints, decisions, or vocabulary earlier in the conversation. Handing that down costs a
few lines of prompt; withholding it costs one redundant re-orientation *per agent*. The test
of a good brief: the agent's **first tool call opens a file you named** — if its first move
would be `ls`/`grep` just to figure out where things are, the brief is missing context you had.

A good brief includes:
- The **scope** (which directory/module/concern it owns) and explicit out-of-scope notes.
- The **known starting points** — the Step 1 facts that fall inside this agent's section:
  the stack/framework, how the app is built/run, the entry files and key paths you already
  spotted (each as `path` or `path:line` with one line on what it is), and the relevant
  directory layout. Name the files it should open first.
- The **questions to answer** — be concrete: "How does data flow from the API into the
  store?", "Where is auth enforced and is it consistent?", "What's the error-handling
  pattern here?", "What does this module depend on and what depends on it?"
- The **task context** — why we're exploring (so it surfaces what's relevant), e.g.
  "we're auditing for security issues" vs. "we're about to rename X everywhere" — **plus**
  everything from the conversation that bears on it: the user's original ask (verbatim if
  short), constraints, decisions already made, domain/project vocabulary. Don't summarize
  this away; the agent can't ask follow-up questions mid-run.
- The **search-breadth hint** the Explore agent expects — `"medium"` for a moderate
  sweep, `"very thorough"` when it must check multiple locations and naming conventions.
- The **return format**: a tight structured summary — key files (`path:line`), the
  patterns/abstractions in use, dependencies in/out, anything that smells off, and open
  questions. Tell it its final message IS the deliverable, so it should return findings,
  not narration.

Example brief:
> **Explore the data layer** (`src/data/`, `src/repositories/`, any ORM/query code).
> Context: Node/Express + Prisma app (schema at `prisma/schema.prisma`); dev runs via
> `npm run dev`. Start from `src/data/client.ts` (the Prisma client wrapper) and
> `src/repositories/index.ts` (barrel of all repositories). We're doing a full codebase
> review, focused on architecture and performance — the user is worried about slow list
> endpoints.
> Answer: What persistence/ORM is used and how? How is data access abstracted (repository
> pattern? raw queries?)? Are there N+1 risks or unbounded queries? What does this layer
> depend on, and which modules depend on it? Search breadth: very thorough.
> Return: key files with `path:line`, the data-access pattern, a dependency sketch, and a
> list of anything that looks off — as a structured summary, not prose.

If, while reading results, a section turns out bigger or more tangled than expected,
**dispatch a follow-up Explore agent** to go deeper on the hot spot rather than trying to
absorb it all yourself — and hand it the earlier agents' relevant findings plus your
accumulated map, so it starts where the last one stopped instead of retracing the section
from scratch.

### Step 4 — Synthesize into one mental model

The subagents return fragments; your job is to make them a whole. Don't just concatenate —
**integrate**:

1. **Assemble the map** — combine each section's findings into a single picture of the
   architecture, the data/control flow, and the key abstractions.
2. **Connect across sections** — the most important findings live at the seams (how auth
   threads through the API and the UI, how a change in the data layer ripples up). Trace
   these cross-section threads explicitly; they're what no single agent could see.
3. **Reconcile conflicts and gaps** — if two agents describe the same thing differently,
   resolve it (read the code yourself if needed). If a question went unanswered, send a
   targeted follow-up.
4. **State your confidence** — note which parts you understand solidly and which are still
   fuzzy, so downstream work (a review, a refactor, an answer) knows where the risk is.

The output of this skill is a **grounded understanding** you then hand to whatever comes
next — a codebase review's feedback phase, a codebase-wide change's inventory, or a
direct, well-supported answer to the user's question.

---

## Relationship to the senior-engineer family

This is the shared exploration engine. Other skills lean on it:

- **`codebase-review`** uses this for its "Explore and Understand" phase.
- **`codebase-wide-change`** uses this to build an exhaustive inventory when the change
  spans many modules.
- When the user asks the **`senior-engineer`** persona a hard question about the code and
  wants it investigated properly, route into this skill first, then answer.

When the exploration is done and you're handing off, say so briefly ("Explored across N
sections; here's the model"), then continue with the task that needed it.
