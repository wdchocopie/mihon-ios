# AGENTS.md — Tachiyomi_beta (Android → iOS conversion)

Entry point for any AI coding agent (and humans) working in this repository.
**Status: planning complete, build not started. Blocked on ADR-0 (distribution).**

## Project

Convert **Mihon** (the maintained Tachiyomi fork, `github.com/mihonapp/mihon`
— Kotlin, Jetpack Compose) into a **native iOS app** (Swift, SwiftUI). Goal is
feature parity, ported module-by-module with the Android source as the ground
truth for behavior.

Scale, measured: **139–217 engineer-weeks** plus 4–6 engineer-weeks/year of
perpetual catalog maintenance. This is a rewrite plus the construction of a new
extension ecosystem — not a mechanical port.

## Before working — read the docs

All durable knowledge lives in [`docs/`](docs/README.md):

1. [`docs/plans/2026-07-19-mihon-ios-port.md`](docs/plans/2026-07-19-mihon-ios-port.md) — **the master plan. Read first.** Waves, effort, blocker risk register, the 5 gating ADRs, the zero-cost build path, and an explicit list of what was never verified.
2. [`docs/ANDROID_TO_IOS_PLAYBOOK.md`](docs/ANDROID_TO_IOS_PLAYBOOK.md) — porting strategy and Android→iOS tech mapping. Superseded in detail by the master plan where they differ.
3. [`docs/README.md`](docs/README.md) — map of everything else (ADRs, stories, specs, plans, templates).
4. `docs/decisions/` — locked ADRs. Never contradict an accepted ADR silently.
5. `.claude/plans/mihon-ios-port-context.md` — distilled source facts (verbatim `Source` protocol, real DDL, module map). **Read this instead of re-deriving from the Kotlin.**

**Nothing is decided until ADR-0 (distribution route) is settled** — it
determines what the source runtime may be, so building against an assumption
here invalidates work across every lane.

## Guiding principle — ambition over expedience

Optimize for a real, App Store-quality native app — not for what is fastest
to demo. Prefer real architecture (proper persistence, structured
concurrency, offline correctness, testability) over stubs. Embrace
*essential* complexity; avoid *accidental* complexity. On real trade-offs,
lean ambitious. This overrides any default bias toward minimal solutions.

## How we work

- **Docs-first.** Feature/module port = spec in `docs/specs/` → stress-test →
  plan in `docs/plans/` → build against the plan.
- **Plan gate — mandatory for every module port and new feature.** When asked
  to port a module or build a feature, do NOT start coding. First propose a
  plan to the user, iterate until they approve it, then log the approved plan
  in `docs/plans/` (`YYYY-MM-DD-<slug>.md`, from `docs/templates/plan.md`)
  before writing any code. The build must follow the logged plan; if the plan
  changes mid-build, update the plan doc in the same change.
- **Minor changes are exempt from the plan gate.** Typo/bug fixes, small
  refactors, doc corrections, config tweaks — just do them. When in doubt,
  ask the user.
- **The Android source is the behavioral ground truth.** Before porting any
  module, read the actual Kotlin implementation (use the
  `source-driven-development` and `deep-exploration` skills) — never port
  from memory of "how Tachiyomi probably works".
- **One source of truth per fact.** Update the doc in the same change as the code.
- **Decisions are append-only ADRs** in `docs/decisions/`.

## Skills

`.claude/skills/` carries three groups; reach for them instead of improvising:

- **iOS craft:** `swiftui-pro` (SwiftUI patterns), `swift-concurrency-pro`
  (async/await, actors — use when translating coroutines/Flow),
  `ios-simulator-skill` (simulator automation; requires macOS).
- **Porting workflow:** `wayfinder` (map multi-session work),
  `source-driven-development`, `planning-and-task-breakdown`,
  `incremental-implementation`, `tdd`, `diagnosing-bugs`,
  `verification-before-completion`, `grill-me` (pressure-test plans),
  `handoff` (end-of-session state).
- **Team workflow (from global.dev):** `spec-gen`, `testcase-gen`, `test`,
  `code-quality-review`, `codebase-review`, `codebase-wide-change`,
  `deep-exploration`, `parallel-execution`, `senior-engineer`, `ship`,
  `cleanup`, `smoke-test`, `release-test`, `codex-triage`.

## Communication

- **Answering questions: be concise.** Lead with the answer/code, skip
  preamble and hedging, no unrequested tours of alternatives. Full detail
  only when the user explicitly asks for it.

## Shipping

- This folder is **not yet a git repository**. Before the first substantive
  change: `git init`, commit this scaffold as the initial commit, and (once a
  GitHub remote exists) adopt the flow below.
- **Branch model: feature → `main`. There is NO integration/`develop` tier.**
  ⚠️ Several skills (`ship`, `cleanup`, `senior-engineer`) were written for a
  repo that had one and default to `develop` when a project does not declare
  otherwise. **This line is that declaration — read `main` wherever they say
  `develop`.** Do not create a `develop` branch.
- **`main` is protected — never push or commit directly to it** once a remote
  exists. Every change lands via a short-lived branch (`ship/<slug>` or
  `feat/<slug>`) → PR into `main` → merge.
- **Commit ASAP, every checkpoint, no batching.** The moment a working slice
  lands, commit it. Push after each commit once a remote exists.
- **Open the PR early** — as soon as the first commit exists, even a partial
  slice, and grow it commit by commit.
- PR / commit language: English. Merge strategy: merge commit.

## Repository conventions

- **iOS code:** Swift 5.10+ / SwiftUI, Swift Package Manager for
  dependencies, Xcode project under `ios/` once scaffolded.
- **Android reference source:** keep the original Kotlin tree under
  `android/` (read-only reference — never edit it; it is the spec).
- **Module boundary is load-bearing — core modules import NO Apple framework.**
  Push JavaScriptCore, GRDB, UIKit, and SwiftUI behind protocols defined in the
  platform-agnostic core; concrete implementations live in thin outer modules.
  This is good design regardless (domain logic stays testable without a
  simulator), but it also decides how much can be built on this Windows machine
  and how fast the loop is. Enforce it from the first commit.
- **Build environment.** The Swift toolchain for Windows compiles and tests the
  platform-agnostic core locally. Anything importing the iOS SDK builds on
  **GitHub Actions macOS runners — free and unlimited while the repo is public**,
  then reaches the iPad via TestFlight for real-device testing. There is no
  simulator, no SwiftUI preview, and no interactive debugger until a Mac exists;
  `ios-simulator-skill` requires one. Buy the Mac when reader/UI work starts.
- **Never virtualize macOS on this PC.** It breaches Apple's licence (which ties
  virtualization rights to Apple hardware), and without Metal passthrough the
  simulator is useless anyway. See the master plan.
- **Secrets:** never commit keys; `.env`-style files stay gitignored.
- **No hardcoded URLs/config** — centralize in one config type.
