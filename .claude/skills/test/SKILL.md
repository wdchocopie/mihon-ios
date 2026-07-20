---
name: test
description: >-
  Orchestrates end-to-end feature testing of the LIVE running app by fanning work across parallel
  subagents — UI flows driven in real browsers via multiple Playwright MCP servers, AND backend/API
  flows verified directly against the running services (source + API calls, no browser) — all running
  simultaneously, one flow per subagent. Use whenever the user wants to test, QA, smoke-test, verify,
  or check that a feature, page, endpoint, or user flow actually works in the running app — triggered
  by "/test", "/test here", "/test all", "/test docs", "test this feature", "QA the changes", "does
  this flow work", "verify the API", or after building/changing a feature that needs human-style
  verification. Also the verification engine the senior-engineer family hands its build's test phase
  to. Maintains a TEST_MATRIX.md of documented flows. NOT for unit/integration tests in code (that's
  a normal test runner) and NOT for a single quick check you can eyeball — this is for multi-flow
  verification fanned across parallel agents.
version: 1.2.0
---

# /test — Parallel feature testing across two tracks

This skill QA-tests a running app the way a human would, fanning **one flow per subagent** out across
two complementary tracks that run **simultaneously**:

- **UI track** — opens **real browsers** through several **isolated Playwright MCP servers at once**
  and drives each user-facing flow click-by-click. This is the human-eyes track: it catches
  rendering, console, navigation, and UX problems.
- **Backend/API track** — verifies server-side behavior **without a browser**: subagents read the
  source, hit the running endpoints directly (curl/HTTP), and check persistence/DB state. This is the
  contract track: it catches status codes, payload shapes, validation, auth/RBAC, and data-layer
  correctness — the things a browser flow either can't see or only sees indirectly.

Both tracks share the same machinery (enumerate → document → decompose → fan out → report), and a
single run routinely mixes them: a feature with a UI *and* an API gets browser flows for the screens
and API flows for the endpoints, launched together. The split matters because the two tracks have
different needs — UI flows are bottlenecked by the number of Playwright servers (one browser each),
while backend/API flows are plain subagents with no server cap, so you can fan those out as widely as
the case list warrants.

The catalog of testable flows lives in `TEST_MATRIX.md` so testing is repeatable and nothing silently
goes uncovered.

The guiding bias: **be thorough and fast.** Before fanning out, think **extremely long and hard** to
enumerate *every* case, story, and state that can happen to the target (Phase 1.5) — across **both**
the UI and the backend/API — because coverage gaps are the one failure this skill exists to prevent.
Then decompose aggressively, fan out widely, and prefer speed slightly over token cost. Always
document before testing, and never run without a known target.

## Prerequisite — Playwright MCP servers (needed for the UI track; ask Claude to set them up)

The **UI track** cannot run without **Playwright MCP servers**, and they are **not installed by
default**. Surface this early — don't get halfway into a run and discover there's no browser to drive.
The **backend/API track needs none of this** — it uses plain subagents with Bash/HTTP and source
access, so it runs even when zero Playwright servers are configured. So a missing-Playwright situation
doesn't block the whole run: do the backend/API flows now, and offer to set up Playwright for the UI
flows (below) rather than stalling.

- **If none are configured, the user needs to ask Claude to install them — and Claude does the install.**
  This isn't something the user has to wire up by hand: when they say something like *"install the
  Playwright MCP servers for /test"* (or you detect none in Phase 0), **you** add them per
  `references/mcp-setup.md`, or point them at the repo's `install.sh --playwright`. Then they restart
  Claude Code so the servers connect.
- **Parallelism comes entirely from running multiple servers.** One Playwright MCP server = one browser
  = one flow at a time, i.e. **no parallelism**. To test N flows simultaneously you must have **N
  separate servers** configured (`playwright`, `playwright2`, `playwright3`, … — **minimum 3, no upper
  limit**). If only one server exists, this skill is reduced to serial testing — so when you find fewer
  servers than the run needs, **offer to add more before fanning out** (and if there are still fewer
  servers than flows, run in waves sized to the server count).

See `references/mcp-setup.md` for detection, the exact `--isolated` server config, and why separate
servers (not tabs) are the only way to get true parallel sessions.

## Commands

Parse the invocation argument first:

- **`/test`** or **`/test here`** → test only what changed **in this session** (what was just built).
- **`/test all`** → test everything documented in `TEST_MATRIX.md` plus all detected changes across the codebase.
- **`/test docs`** / `/test doc` / `/test document …` → **documentation only**. Run the investigation + documentation phases, update `TEST_MATRIX.md`, then **stop and wait** for the user to confirm before any browser runs.

No argument behaves like `/test here`.

---

## Phase 0 — Prepare & investigate (always run this first)

Do this on **every** invocation, including `/test docs`, before anything else. If the
**deep-exploration** skill is available, use it for the codebase investigation; otherwise
investigate manually (Glob/Grep/Read, git diff).

1. **Figure out what's under test.**
   - `/test here`: read this session's history to see what was built/changed. If the session has no clear build context, read `TEST_MATRIX.md`. If that file doesn't exist, read `AGENTS.md` (and `CLAUDE.md`/`README.md`) to orient.
   - `/test all`: enumerate everything in `TEST_MATRIX.md` **and** scan for changes (below).
2. **Read the docs that matter.** Read `TEST_MATRIX.md` and `AGENTS.md`, then follow their references to any feature-specific docs relevant to the target (specs, ADRs, design notes). Don't skim — these define expected behavior and the flows you'll assert against.
3. **Scan the codebase for untested changes.** Look for recent changes (git status/diff if available, or recently-modified source) that touch user-facing behavior and are **not** documented in `TEST_MATRIX.md`. If you find some, **list them and ask the user** whether to include them in this run (they may be intentional out-of-scope work).
4. **Confirm the tooling is present** (see `references/mcp-setup.md`). This is **only for the UI
   track** — the backend/API track needs no Playwright at all, so if a run is backend-only, skip
   this step entirely. When the run has UI flows:
   - **Playwright MCP installed?** If memory says the user already has it, skip the check and proceed. Otherwise verify a `playwright*` MCP server exists; if none, **don't abort the whole run** — run the backend/API flows now, and offer to install Playwright (you do the install per `references/mcp-setup.md`) so the UI flows can run after a restart.
   - **Enough parallel servers?** The UI track needs several isolated Playwright MCP servers, named `playwright`, `playwright2`, `playwright3`, … — **as many as the user wants, with a minimum of 3 and no upper limit.** Detect how many are *currently* configured (check both the project `.mcp.json` / project block of `~/.claude.json` and the global config); never assume a fixed number. If there are fewer than 3, or fewer than the number of **UI** flows you intend to run, **help the user add more isolated ones** — default to enough to cover the UI flows, and always at least 3. See `references/mcp-setup.md`. Newly added servers require a Claude Code restart to connect. (The backend/API flows are unaffected by the server count — they run regardless.)
5. **Verify accounts + data state BEFORE fanning out — cheap up front, expensive mid-run.** A tester
   that discovers a missing login or an empty queue halfway through has already burned a whole browser
   session. Pre-flight it with a few quick API calls (not browsers):
   - **Accounts:** for each Role the in-scope flows will use, do a quick API login (e.g. `curl` the
     auth endpoint) to confirm the account exists and the password works. Missing/seed-needed users are
     a blocker to fix now (seed/create), not for an agent to hit live.
   - **Data preconditions:** for each in-scope flow, confirm its required data actually exists — query
     the API/DB for "is there a record at status X / a non-empty queue / a book in stage Y?" If a flow
     needs a record in a state nothing is currently in, that flow is blocked until you seed/promote one.
   - **Also sanity-check the endpoints the flows lean on** (hit the key API route with a real token):
     a route that 500s for everyone (often masked as a CORS error in the browser) blocks every flow that
     touches it — far cheaper to catch here than via N failed browser runs.
   - Record every gap in the matrix's **Known issues / data prerequisites** section and resolve or scope
     it out with the user before Phase 3, so no agent wastes a session on a known-dead flow.

---

## Phase 1 — Document the flows (gate before any test)

A flow may only be tested once it's written down. This keeps runs reproducible and reviewable.

1. **If `TEST_MATRIX.md` doesn't exist**, offer to create one from `assets/TEST_MATRIX.template.md` and explain what it's for.
2. **If the requested feature's flows aren't documented**, interview the user to capture them. Ask **as many questions as needed, up to 7**, to nail down: the entry point/URL, the login role(s) and credentials, the exact step sequence, the expected outcome / pass criteria, edge cases, and how to tell success from failure. Then write the flows into `TEST_MATRIX.md` (format in `references/test-matrix-format.md`).
3. **If the docs are missing pieces** you uncovered in Phase 0 (undocumented changes the user agreed to test, or gaps in an existing entry), document those too, and **ask the user to confirm** the documented set before proceeding.
4. **`/test docs` stops here** — present what you documented and wait. Do not launch browsers.

---

## Phase 1.5 — Enumerate ALL the cases (mandatory thinking gate)

**Do not skip this and do not rush it.** This is where coverage is won or lost. Open
`references/case-enumeration.md` and follow its process in full: think **extremely long and hard**,
walk **every** dimension, and produce an exhaustive case list — then attack your own list with
"what else can happen?" until two consecutive passes add nothing new.

- A "case" is a distinct **story** (a path/state through the feature), not a UI click: `who ·
  precondition/state · action · expected outcome`. Cover happy paths *and* their variations, every
  role (allowed and blocked), every input/validation case, every entity status, empty/one/many/over-
  limit, error & failure paths (4xx/5xx/network), concurrency, persistence-after-refresh, navigation,
  cross-module ripples, responsive/a11y, and localization — per the reference's dimensions.
- **Record the case list in `TEST_MATRIX.md`** alongside the flows so coverage is visible and
  reproducible. Tag each case P0/P1/P2; nothing gets dropped from the list — priority only governs
  run order when the parallel budget is tight.
- For `/test here`, enumerate exhaustively for the **changed** surface; for `/test all`, for every
  documented feature in scope. If a case's expected outcome is genuinely unknown, surface it as an
  open question for the user rather than silently omitting it.
- **`/test docs` includes this enumeration** in what it documents, then still stops before browsers.

This list is the input to Phase 3's decomposition — you cannot decompose into flows what you haven't
first enumerated as cases.

---

## Phase 2 — Pick the subagent model (hard gate)

The tester subagents run on a **cheaper/faster model** — never the orchestrator's model, to control cost.

- Check `TEST_MATRIX.md` (its config/front-matter section) for a user-defined `subagent_model`.
- **If none is defined, STOP and ask the user which model to use.** Do not guess a default. Once they answer, record it in `TEST_MATRIX.md` so future runs don't re-ask.

**Right-size the model per flow — this is the default, not an afterthought.** A flow's model should
match its difficulty, not a single blanket choice. Pick per flow:

- **`claude-haiku`** for simple flows — gating checks, navigation, smoke tests, read-only assertions,
  "does this page render" — where there's no branching or judgment. These dominate most matrices.
- **`claude-sonnet`** for flows with branching, forms, multi-step state, or judgment (security/RBAC
  probing, conflict resolution, anything where the agent must reason about what it sees).

Why this matters: defaulting *everything* to the stronger model silently doubles cost on the many
flows that didn't need it. If `subagent_model` is set to a single value, honor it; if it's `mixed`,
choose per flow using the split above (tag each flow's tier when you decompose in Phase 3).

---

## Phase 3 — Orchestrate the parallel run (two tracks)

This is the core. Read `references/subagent-prompt.md` for both briefing templates — the **UI/browser**
template and the **backend/API** template.

1. **Decompose the Phase-1.5 case list into flows, and tag each flow's track.** Group the enumerated
   cases into independent, self-contained flows/user-stories — **every P0 and P1 case must land in some
   flow**; don't quietly leave cases untested. As you carve each flow, mark whether it's a **UI flow**
   (something a human verifies through the screen — rendering, clicks, navigation, forms, visual state)
   or a **backend/API flow** (something verified server-side — endpoint status/payload, validation,
   auth/RBAC, persistence, business rules, jobs/webhooks). A case that has both a screen and an
   endpoint usually splits into two flows, one per track, so each is checked with the right tool.
   **Be aggressive — never fewer than 3 subagents total; 4–5+ is the sweet spot, and an honestly-
   enumerated feature usually needs more.** Split by role, by path, by happy/edge/error case — favor
   more, narrower agents over a few broad ones. We optimize for speed and coverage over frugality.
   If a wave can't cover every case at once, run additional waves rather than dropping cases.
   As you decompose, **tag each flow with its model tier** (Phase 2) and **give it a step budget** —
   a cap on how much the tester should explore (e.g. "step through ≤6 representative items, one per
   distinct type/state — not all of them" and "≤2 attempts per control/endpoint, stop once the outcome
   is confirmed or clearly fails"). Open-ended flows balloon: in past runs a single agent spent 140+
   tool calls grinding one control, or stepped 14 near-identical items when 6 covered the matrix. A
   narrow flow with a budget is cheaper and sharper than a broad one without.
2. **Assign resources per track.**
   - **UI flows → one isolated MCP server each.** Map UI flow 1 → `playwright`, UI flow 2 →
     `playwright2`, … Each UI subagent must use **only its assigned namespace** (e.g.
     `mcp__playwright3__*`) — sharing one browser across agents makes them collide. Use as many servers
     as are configured (**minimum 3, no maximum**); if there are more UI flows than servers, run the
     UI flows in **waves sized to the number of servers**.
   - **Backend/API flows → plain subagents, no server, no cap.** They need no Playwright namespace, so
     they aren't bottlenecked by server count — fan out as many as the case list warrants (they each
     use Bash/`curl`/HTTP plus `Read`/`Grep` on the source). They run **in the same wave** as the UI
     flows, so the two tracks execute concurrently.
3. **Dispatch them ALL at once — every flow, both tracks, in ONE message.** Launch *all* of the
   wave's subagents in a **single message** (multiple Agent tool calls at once) so they truly run in
   parallel. The count you launch equals the number of flows the wave covers: enumerated 6 flows and
   have the servers for them? **6 Agent calls go out together — not 2 now and 4 after.**

   **Do not stage a "canary" or "smoke-first" batch.** The tempting move — fire 1–2 simple flows
   first, wait to confirm "no JS errors / grading works," then launch the rest — is precisely the
   split to avoid. It serializes what should be parallel and roughly doubles wall-clock, while buying
   almost nothing: a *systemic* problem (broken login, dead dev server, a bad selector pattern) surfaces
   just as fast when all flows start together, and every subagent already reports its own failure
   independently. Your pre-flight sanity check already happened in **Phase 0** (the cheap API/login/data
   probes) — that is where de-risking belongs, not in a half-wave of real browser flows. So once you've
   decided the flow list, commit to it: one message, all of them.

   **Don't batch by model tier either.** Haiku and sonnet flows launch in the *same* message — the tier
   only sets each Agent call's `model`, it never splits the dispatch. Mixing `claude-haiku` and
   `claude-sonnet` Agent calls in a single message is expected and fine.

   Use `subagent_type: general-purpose` for **both** tracks (NOT the built-in `tester` agent — it's
   hard-wired to `mcp__playwright__*` only, can't see the other servers, and isn't needed for the
   no-browser backend flows). Set each Agent call's `model` to that flow's chosen tier (Phase 2).

   **The ONE and only reason to split across more than one message: too few Playwright servers for the
   UI flows.** If you have N UI flows but only M < N servers configured, the UI track runs in waves of
   M (Step 2's server-sized waves) — a hardware limit, not a judgment call — and you say so out loud
   ("5 UI flows, 3 servers → two UI waves"). Even then, **backend/API flows have no server cap, so every
   backend flow still goes in the first message.** When servers ≥ UI flows (you currently have up to 10),
   there is no split at all: every flow fires simultaneously.
4. **Each subagent follows its track's template.**
   - **UI subagent:** loads its server's deferred tools via ToolSearch, logs in with the documented
     role, performs its flow step-by-step taking snapshots/screenshots, watches the browser console +
     network for errors, and returns a **structured verdict** (steps done, per-step observations,
     console/HTTP errors, PASS/FAIL with justification). Tell them to leave the browser open so you can
     spot-check, then you close it in Phase 5.
   - **Backend/API subagent:** reads the relevant source to learn the contract, authenticates via the
     API (token/cookie), exercises each endpoint/rule with `curl`/HTTP — asserting on **status code,
     payload shape, and durable state** (DB row written, record advanced) — probes the error and
     auth/RBAC cases, and returns the same **structured verdict**. No browser to leave open, so nothing
     to clean up for these.

**Default to full live runs on both tracks.** Only fall back to a pre-written script (Phase 5) when
it's *truly* obvious the flow is mechanical and high-volume — be strict; the live run is the default
because it catches rendering/console/UX problems (UI) and real status/payload/state problems (backend)
that a script glosses over.

---

## Phase 4 — Report

Aggregate the subagents' results into one report for human QA:

- **Per-flow verdict** (✅ pass / ⚠️ partial / 🚫 blocked), labeled by track (UI / backend·API), with the key evidence — console/HTTP errors for UI flows, status/payload/state assertions for backend flows.
- **Cross-cutting findings** — bugs, blockers, or data-state issues that affect multiple flows. When a browser (UI flow) reports a CORS/`ERR_FAILED` on an API call, suspect a backend 5xx that stripped CORS headers — and the **backend flow that hit the same endpoint directly will usually have already nailed the real status**, so cross-reference the two tracks before calling it a CORS-config problem.
- **Coverage gaps** — cross-reference results against the **Phase-1.5 case list**: every enumerated
  case should be run, deferred (with reason), or flagged inconclusive. Report cases run vs. enumerated
  (and which P-tier was deferred). Never present partial coverage as complete.

---

## Phase 5 — Repeatability & cleanup (after every run)

1. **Only suggest a repeatable script when it's genuinely justified — default to NOT suggesting.**
   Most flows should just stay on live MCP; floating a "want a script?" idea after every run is noise
   that trains the user to ignore you. Stay **silent** unless *all* of these clearly hold:
   - the flow is **mechanical and fully deterministic** — no human-like judgment or visual assessment that an agent is needed for;
   - its **UI is stable**, not under active development (a script written against churning UI just rots); and
   - it will **genuinely be re-run often** as a regression check — the user runs it repeatedly, or has explicitly asked for regression coverage.

   A one-off verification, an exploratory flow, or anything tied to changing UI is **not** a
   candidate — say nothing. When the bar truly is met, make the offer **once**, briefly, with the
   concrete payoff (a regression flow re-run many times saves ~40–80k tokens each run); on the user's
   OK, write the script and record it under "Repeatable scripts" in `TEST_MATRIX.md`. When in doubt,
   don't suggest.
2. **Clean up automatically once the Phase-4 report is delivered — this is the default, not an offer.**
   A `/test` run leaves browser sessions and a pile of artifact files behind; leaving them is the
   annoyance this step exists to prevent. Do the cleanup **yourself**, right after the report is in front
   of the user — the report has already conveyed the findings and evidence, so nothing is lost by tidying
   up. Two kinds of debris:
   - **Open browser sessions / Playwright instances (UI flows only).** Every UI tester was told to leave
     its browser open (Phase 3) so you could spot-check; that's done once the report is written. Close
     **every** namespace the run used — call `mcp__<server>__browser_close` for *each* of `playwright`,
     `playwright2`, `playwright3`, … (not just the first), then sweep any stray browser processes the wave
     spawned (e.g. a leftover headless Chrome from a crashed session). Headful browsers left running leak
     memory and slow the next run, and there's never a reason to keep one — so **closing them is
     unconditional**, no need to ask. (Backend/API flows open no browser; nothing to close for them.)
   - **Artifact files the run produced** — **every screenshot taken during the test** (the `.playwright-mcp/`
     dump, which a single multi-flow run can grow to 100+), plus any scratch files the agents wrote (saved
     curl payloads, temp response dumps, throwaway `.js`/`.json` scratch). **Delete all of it by default.**
     The report you just delivered already carries the findings — including the evidence for any
     failure/blocker described in text — so the screenshot files themselves are throwaway and should go.
     The **only** things you keep are what's explicitly worth reusing: (a) any artifact the **user
     explicitly asked you to keep** ("leave the screenshots", "don't delete the failure shots"); and (b)
     any **approved regression script** recorded under "Repeatable scripts" in `TEST_MATRIX.md` (and the
     matrix itself). Absent an explicit ask, clear the screenshots too — `rm -rf .playwright-mcp/` and any
     ad-hoc scratch dirs. Then state in **one line** what you did: e.g. "Cleaned 94 screenshots + 2 scratch
     files." If the user *did* ask to keep some, preserve just those and tell them the path.
   - **If there's nothing to clean** (no sessions open, no artifacts), say so in one line and move on —
     don't manufacture work.

   The principle is *clean up after yourself unless an artifact will plausibly be reused.* Beyond this
   run's own debris, if the repo has accumulated a lot of *stale* test/build cache, point it out and offer
   to clear it — but never delete pre-existing files this run didn't create without asking.

---

## Reference files
- `references/case-enumeration.md` — **(Phase 1.5)** the exhaustive case/story taxonomy and the think-long-and-hard enumeration process. Read it every run.
- `references/mcp-setup.md` — detect, install, and configure the parallel Playwright MCP servers (isolated).
- `references/subagent-prompt.md` — the per-flow tester subagent briefing templates (one for **UI/browser** flows, one for **backend/API** flows).
- `references/test-matrix-format.md` — structure of `TEST_MATRIX.md` and the config keys this skill reads.
- `assets/TEST_MATRIX.template.md` — starter file to copy when a project has none.
