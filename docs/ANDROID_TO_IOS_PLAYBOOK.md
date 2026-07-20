# Android → iOS Conversion Playbook

**Status:** accepted
**Scope:** Converting the Tachiyomi Android app (Kotlin / Jetpack Compose)
into a native iOS app (Swift / SwiftUI). This is the standing reference for
how the port is done; per-module detail goes in `specs/` and `plans/`.

## Ground rules

1. **The Android source is the spec.** Every ported behavior is grounded in
   the actual Kotlin code (`source-driven-development` skill), not in memory
   of how the app "probably" works. Keep the Android tree in the repo as a
   read-only reference.
2. **Port module-by-module, verify each slice** (`incremental-implementation`
   skill). Never a big-bang rewrite: each ported module gets its own spec,
   plan, tests, and a working checkpoint before the next begins.
3. **Idiomatic Swift, not transliterated Kotlin.** Match iOS platform
   conventions (structured concurrency, value types, SwiftUI data flow) even
   when the Android code does it differently. Behavior parity, not
   line-by-line parity.
4. **Decisions become ADRs.** Anything from the "Open architecture
   decisions" section below gets settled in `docs/decisions/` before the
   affected module is built.

## Phases

| Phase | What | Skills to use |
|-------|------|---------------|
| 0. Inventory | Map the Android codebase: modules, screens, data flows, dependencies | `deep-exploration`, `codebase-review`, `wayfinder` |
| 1. Architecture | Settle the open decisions below as ADRs | `grill-me`, `spec-gen` |
| 2. Scaffold | Xcode project, SPM deps, CI, theme tokens | `swiftui-pro` |
| 3. Core/data layer | Models, persistence, networking, source API — no UI | `source-driven-development`, `tdd`, `swift-concurrency-pro` |
| 4. UI | Screen-by-screen SwiftUI port | `swiftui-pro`, `incremental-implementation` |
| 5. Verify | Simulator runs, test matrix, release checks | `ios-simulator-skill`, `testcase-gen`, `test`, `release-test` |

Every session ends with a `handoff` (see `docs/handoff/`).

## Tech mapping (Android → iOS)

| Android (Tachiyomi) | iOS equivalent | Notes |
|---|---|---|
| Kotlin | Swift | Value semantics; `struct` over `class` where possible |
| Jetpack Compose UI | SwiftUI | Closest analog; recomposition ≈ view invalidation |
| Voyager navigation | `NavigationStack` + router | Model navigation state explicitly |
| Coroutines + `Flow` | async/await + `AsyncSequence`/`AsyncStream` | See `swift-concurrency-pro`; `StateFlow` ≈ `@Observable` model + async stream |
| `Dispatchers.Main` | `@MainActor` | Annotate UI-facing types |
| SQLDelight (SQLite) | **GRDB.swift** — decided, not a toss-up | SwiftData cannot express the 5 triggers, 3 views, the 3-CTE duplicate query, or trigger-aware observation. Keep triggers in SQL. |
| OkHttp (+ interceptors) | `URLSession` | Cookie handling and Cloudflare challenges need a `WKWebView`-assisted path |
| kotlinx.serialization | `Codable` | |
| Coil (image loading) | **Nuke** or Kingfisher | Disk cache tuning matters for page images |
| WorkManager (library update jobs) | `BGTaskScheduler` (`BGAppRefreshTask`/`BGProcessingTask`) | **Far more restrictive on iOS** — no guaranteed schedule; design updates as opportunistic + foreground-driven |
| SharedPreferences / Preference wrapper | `UserDefaults` + `@AppStorage` facade | Keep one typed preferences layer like the Android one |
| Injekt (service locator DI) | Composition root (manual) or Factory/swift-dependencies | Decide once, ADR it |
| Storage Access Framework, downloads | `FileManager` + security-scoped bookmarks, `UIDocumentPicker` | Download folder semantics differ; on-device sandbox only |
| Notifications / foreground services | `UNUserNotificationCenter`; **no long-running services** | Downloads must survive via `URLSession` background sessions |
| Material 3 theme | Custom SwiftUI theme tokens | |

## The hard problem: the extension system

> **Superseded in detail by the [master conversion plan](plans/2026-07-19-mihon-ios-port.md)**,
> which is grounded in a measured 6-lane analysis plus 3 adversarial reviews.
> This section is the short version; the plan is authoritative.

Mihon loads catalog sources as **separate signed APKs**, discovered via
`PackageManager`, trust-checked by SHA-256 signing certificate, and
instantiated by reflection in a `ChildFirstPathClassLoader`
(`ExtensionLoader.kt:282-310`). The loaded object is a **live Kotlin instance**
with full access to OkHttp, Jsoup, RxJava, and androidx.preference — the
contract is executable behavior, not data. iOS forbids this under every
distribution channel, so it has no port; it must be replaced by an interpreter
the OS permits.

**Decision (ADR-1, pending sign-off): JavaScriptCore + a Cheerio-equivalent
DOM layer.** It survived all three adversarial lenses, on two independent
grounds: Jsoup selectors port near-mechanically to Cheerio (the only lever that
scales across a four-digit catalog), and Guideline 4.7 permits non-embedded
"HTML5 and JavaScript mini apps... and plug-ins" **by name and names nothing
else** — so WASM is both costlier to port and policy-disfavored. JSC's lack of
JIT is not a handicap: iOS forbids W^X to all non-WebKit processes, making a
WASM runtime equally interpreted.

**The theme lever — measured, and the reason this is tractable at all.**
53.8% of the 1,367 extensions (736) are *thin subclasses of a shared theme*.
So the unit of work is the **theme**, not the source:

- `madara` alone → **295 extensions**
- `madara` + `mangathemesia` → **440 extensions (32% of the catalog)** from two implementations
- top 10 themes → 570 extensions (41.7%)
- the remaining 631 bespoke sources are strictly linear, ~1 site per port

**Two counting traps to avoid.** The Keiyoushi index ships **APK artifacts
only** — there is no JS or WASM artifact an iOS client could consume, and no
automated Kotlin→JS path exists. And index *entries* are not *reach*: MangaDex's
61 entries are 61 language variants of one website. 94.5% of packages are
single-source. **Count websites, never entries.**

Prior art: **Aidoku** (WASM, sideload-only), **Paperback** and **Suwatte**
(JavaScriptCore).

## Other iOS-specific hazards

- **App Store review:** an app that browses third-party manga aggregators
  risks 4.2/5.2 rejections. Decide early whether the target is App Store,
  TestFlight, or sideloading/AltStore — it changes what the extension
  system may do.
- **Background downloads:** must move to `URLSession` background sessions;
  the Android "download queue while app is closed" UX cannot be replicated
  exactly.
- **Backup import:** Tachiyomi `.tachibk`/protobuf backups should import
  cleanly — this is the migration path for existing users and is high-risk
  lane (data loss potential). Port the backup schema early and test against
  real backup files.
- **Local source:** folder-based local manga must use the iOS document
  picker + security-scoped bookmarks; no arbitrary filesystem access.
- **Reader performance:** page pre-loading, downsampling, and memory caps
  matter more on iOS (jetsam kills). Profile with Instruments once on macOS.

## Toolchain reality

- Swift sources, specs, plans, and tests can be authored on this Windows
  machine, but **building, simulator runs, and signing require macOS +
  Xcode**. `ios-simulator-skill` only works on a Mac.
- Existing iOS readers worth reading for prior art: **Aidoku**
  (github.com/Aidoku/Aidoku), **Suwatte**, **Paperback**.

## Open architecture decisions (→ ADRs before building)

Now tracked with recommendations in [`decisions/README.md`](decisions/README.md)
and justified in the [master plan](plans/2026-07-19-mihon-ios-port.md).
**ADR-0 (distribution) gates all the others** — decide it first.

Summary: ADR-0 two-track distribution (blocked on one verification), ADR-1
JavaScriptCore, ADR-2 GRDB, ADR-3 iOS 17.0, ADR-4 hand-rolled `AppEnvironment`
DI. Trackers: MyAnimeList + AniList in v1; the rest deferred.

## Scale — what this actually costs

**139–217 engineer-weeks (≈2.7–4.2 engineer-years)** for feature parity, plus
**4–6 engineer-weeks/year** of perpetual catalog maintenance that grows linearly
and crosses a full FTE at ~250–300 sources. This is a rewrite of a mature app
*plus* the construction of a new extension ecosystem from zero. The per-lane
breakdown and its cost drivers are in the master plan.
