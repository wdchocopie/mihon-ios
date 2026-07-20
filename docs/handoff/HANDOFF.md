# Handoff — 2026-07-20

**Session:** Planned the port, verified the zero-Mac build path, scaffolded the
SPM skeleton + CI, published the repo, then ran the `.tachibk` decoder spike.
**Branch:** `spike/tachibk-decoder` (off `main`) — open PR into `main`.

## `.tachibk` decoder spike — DONE (2026-07-20)

- **Schema derived from the Mihon source** (the real `@ProtoNumber` annotations),
  logged in `docs/specs/2026-07-20-tachibk-decoder-design.md` — the "derived
  .proto" the plan asked for.
- **Answer to the spike question:** it's gzipped kotlinx-protobuf, and
  swift-protobuf is the WRONG tool — three kotlinx conventions force a
  hand-rolled reader: non-packed repeated scalars, Kotlin default-omission, and
  the polymorphic `PreferenceValue` sealed class. Built a ~200-line dependency-
  free wire reader/writer + models + decoder in `MihonBackup`, all
  platform-agnostic (tests run on Windows).
- **Reading the source caught a data-loss trap (R3):** `BackupManga.favorite`
  defaults to **true** — a naive bool-defaults-false decoder would silently
  un-favorite every restored manga. There's an explicit regression test for it.
- **22 tests green** locally on Windows (11 new backup tests): favorite-default
  guard, full logical round-trip, forward-compat field skipping, container
  detection, MangaRestorer parity rules (tracking remoteId, viewer-flags
  fallback).
- **DEFERRED / pending:** gzip inflate (outer wrapper — magic detection done),
  `PreferenceValue` polymorphic decode, byte-exact export. **R3 is
  "characterized", not "closed"** — closing it needs a REAL `.tachibk` exported
  from Mihon to validate the derived schema against actual bytes. Ask the user.

## Published + verified (2026-07-20)

- **Repo is live and PUBLIC:** https://github.com/wdchocopie/mihon-ios
  (pushed on the `wdchocopie` gh account; `main` tracks `origin/main`).
- **CI green.** `core-tests.yml` ran on the push and passed on the Linux runner
  (free, ~35 s) — proves the scaffold compiles and tests pass, and that the
  no-Apple-framework boundary holds.
- **Local build+test green on Windows** (Swift 6.3.3): `swift build` +
  `swift test` → 10 pass, 1 skipped (`SourceID` golden vectors, pending R4), 0
  fail. So the free local loop is real and working.
- **Toolchain gotcha resolved:** `SDKROOT` must point at
  `…\Swift\Platforms\6.3.3\Windows.platform\Developer\SDKs\Windows.sdk`. It is
  ALREADY persisted in the user env by the installer, so a **fresh terminal**
  works with no action. The failure I first hit was only because this session's
  shell predated the install. (Harmless `.build\debug` symlink warning unless
  Windows Developer Mode is on.)
- Note: the first two commits went directly to `main` to bootstrap the repo.
  **From here, feature/module work uses the branch → PR flow** per AGENTS.md.

## Done earlier this session (scaffold)

- **Module skeleton committed.** Multi-module SPM package, boundary enforced from
  commit 1: `MihonCore` + `MihonBackup` import no Apple framework (verified by
  grep — only Foundation + cross-platform Crypto), build/test on Windows via
  `swift test`. `MihonSources` (JavaScriptCore), `MihonData` (GRDB), `MihonUI`
  (SwiftUI) are `#if canImport`-guarded so the package still builds everywhere.
- **`SourceID` is a real, tested slice** — exact port of `HttpSource.id` MD5
  (plan R4), with property tests that run on Windows. Golden-vector test is
  `XCTSkip`-pending: R4 is NOT closed until real Mihon IDs are pinned.
- Everything else is a boundary-correct `TODO(port)` stub citing its Kotlin
  source + plan risk.
- **CI:** `core-tests.yml` (Linux build+test per push — the boundary gate),
  `ios-build.yml` (macOS: XcodeGen → fastlane match → build → TestFlight, manual
  trigger). `project.yml`, `fastlane/Fastfile`+`Matchfile`, `Gemfile`, `App/`
  entry, `README.md`, `.gitattributes` (LF), `.gitignore`.
- **NOT COMPILED** — authored on Windows with no toolchain installed. First
  `swift build` on a Swift machine is the real check; it fetches swift-crypto.

## Prior session (planning) — still current



## Done this session

- **Scaffolded the workspace** (prior session): `CLAUDE.md` → `AGENTS.md`, 26
  skills in `.claude/skills/`, `docs/` system with templates. See git-less
  `docs/` tree.
- **Fetched both sources:** Mihon (`github.com/mihonapp/mihon`, 905 Kotlin
  files / 81,258 lines / 15 Gradle modules) and the Keiyoushi index
  (1,367 extensions → 2,016 source entries). Later also cloned
  `keiyoushi/extensions-source` to measure themes.
- **Wrote a context pack** at `.claude/plans/mihon-ios-port-context.md` — the
  verbatim `Source` protocol, the real `mangas`/`chapters` DDL including the
  5 triggers, module map, and measured scale. Every agent read this instead of
  re-deriving from raw sources.
- **Ran a 9-agent workflow** (6 analysis lanes + 3 adversarial verifiers), Opus
  at high effort, per the `parallel-execution` skill's distribute-then-dispatch
  procedure. 745k tokens, ~12 min, 0 errors.
- **Measured the theme lever myself** — the number all three verifiers flagged
  as unmeasured and highest-leverage: **53.8% of extensions (736/1367) are thin
  theme subclasses.** `madara` = 295, `mangathemesia` = 145, top 10 = 41.7%.
  This clears the >50% bar that makes a theme-first catalog strategy correct.
- **Wrote `docs/plans/2026-07-19-mihon-ios-port.md`** — the master plan: 5 waves,
  effort table, 9-item blocker risk register, 5 gating ADRs, explicit
  "what I did not verify" section.
- Updated `docs/plans/README.md`, `docs/decisions/README.md` (pending-ADR
  table), and corrected `ANDROID_TO_IOS_PLAYBOOK.md` where yesterday's
  assumptions are now measured.

## In flight (half-done)

- Nothing mid-edit. The plan is complete but **proposed, not approved** — per
  the `AGENTS.md` plan gate it needs sign-off before any code.

## Next up

1. **Verify the Paperback question** (see landmines) — it decides ADR-0.
2. Get user sign-off on ADR-0 distribution, then write ADRs 0–4.
3. `git init` + commit the scaffold and plan.
4. Add the Mihon source under `android/` as read-only reference.
5. Submit the MyAnimeList API application — human-reviewed, calendar time
   starts immediately and cannot be parallelized.
6. Run Wave 0's two spikes (`.tachibk` wire format; bridged-DOM vs Cheerio
   benchmark) and the three timed source ports.

## Landmines / gotchas

- **UNRESOLVED CONFLICT, needs a human call.** Lane 6 says an App Store build
  must have a *statically compiled* source set (2.5.2/3.3.2). The policy
  verifier says Guideline 4.7 affirmatively permits JS plug-ins and that
  **Paperback (JS-based) is on the App Store today while Aidoku (WASM) is not**
  — inverting Lane 6's evidence. The load-bearing unverified fact: whether
  Paperback's *App Store binary* can add arbitrary third-party repos, or only
  its sideloaded build can. **I did not verify this.** ~30 minutes of checking
  decides months of architecture.
- **All 3 adversarial lenses returned holdsUp=false** — but each *kept* the
  JavaScriptCore choice while refuting the reasoning around it. Read their
  corrections before relitigating the runtime: the objections are about the
  ecosystem metric, the Cloudflare mechanism, and the policy basis, not the
  runtime.
- **Cloudflare is commonly misdiagnosed as JA3 fingerprinting.** The real
  mechanism is cookie-store unification (`AndroidCookieJar.kt:10` backs OkHttp's
  jar with Android's `CookieManager`). iOS has no unified store. Budget explicit
  bidirectional WKHTTPCookieStore ↔ HTTPCookieStorage bridging.
- **`JavaScriptEngine.kt:11-25` exposes `evaluate()` to extensions** — sources
  eval *site-supplied* JS. On iOS that would inherit the whole host bridge. A
  second bridge-free `JSContext` is a v1 requirement, not hardening.
- **Index entries ≠ reach.** MangaDex's 61 entries are 61 language variants of
  one site. 94.5% of packages are single-source. Count websites.
- The `extensions-source` repo uses a **new Gradle DSL** (`theme = "madara"`,
  not the old `themePkg = '...'`). An old-syntax grep returns 0 and looks like
  a real answer — it isn't.
- Cloning `global.dev` on Windows needs `core.longpaths=true`.

## Open questions (blocking)

- **ADR-0 distribution** — App Store + sideload two-track, or sideload-only?
  Blocks the runtime design and therefore every other lane.
- **Which Mihon/Tachiyomi tree is the port target?** This session used Mihon
  (the maintained fork) — confirm that's intended.
- Is external contributor inflow expected? The plan assumes **zero**. If there
  is no bootstrap plan, v1 should be 10–15 sources, not ~30.
- Mac access: Mac mini (~$600) or cloud Mac (~$60/mo)? Not optional before
  Wave 3.

## Pick up from

- `docs/plans/2026-07-19-mihon-ios-port.md` — the master plan; start at
  "Three decisions that gate everything".
- `.claude/plans/mihon-ios-port-context.md` — distilled source facts.
- Full 9-agent output (331 KB):
  `C:\Users\WDCHOC~1\AppData\Local\Temp\claude\C--Users-WDchocopie-Downloads-Tachiyomi-beta\92763d0f-1b81-433c-a2e7-1a8255cf779d\tasks\w1h0p3hgp.output`
  (results nested under `.result`, not top level).
- Workflow script (re-runnable / resumable):
  `...\workflows\scripts\mihon-ios-port-plan-wf_67b79504-804.js`, run ID
  `wf_67b79504-804`.
- Command to resume: none (no build yet) — start with `git init` in
  `C:\Users\WDchocopie\Downloads\Tachiyomi_beta`.
