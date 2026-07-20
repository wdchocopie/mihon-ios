# Mihon → iOS Port — Master Conversion Plan

**Status:** proposed — requires your sign-off on the three gating decisions below
before any code is written (per the plan gate in `AGENTS.md`).
**Date:** 2026-07-19
**Basis:** 6-lane parallel analysis of the real Mihon source (905 Kotlin files,
81,258 lines) + the Keiyoushi catalog (1,367 extensions), followed by 3
adversarial verification passes. Context pack:
`.claude/plans/mihon-ios-port-context.md`.

---

## Bottom line

**139–217 engineer-weeks (≈2.7–4.2 engineer-years) for feature parity**, plus
**4–6 engineer-weeks/year of perpetual catalog maintenance** that grows linearly
and crosses one full-time engineer at ~250–300 sources.

This is not a port. It is a **rewrite of a mature app plus the construction of a
new extension ecosystem from zero**. No automated path converts a Kotlin/Jsoup
extension into anything iOS can run — all 1,367 must be rewritten by hand.

The single most valuable finding, and the one that makes this tractable at all,
is measured in "The theme lever" below.

---

## What is actually grounded (measured, not estimated)

| Fact | Value | Source |
|---|---|---|
| Mihon Kotlin | 905 files / 81,258 lines / 15 Gradle modules | direct count |
| Extensions in catalog | 1,367 packages → 2,016 source entries | `index.min.json` |
| **Themed (thin subclass) extensions** | **736 = 53.8%** | `extensions-source` build files |
| Bespoke extensions | 631 = 46.2% | same |
| Largest theme: `madara` | 295 extensions | same |
| 2nd: `mangathemesia` | 145 extensions | same |
| Top 10 themes | 570 extensions = 41.7% of catalog | same |
| Catalog churn (maintenance proxy) | 33,891 version bumps; median 15/ext | index version codes |
| NSFW-flagged packages | 389 of 1,367 | index `nsfw` flag |
| Non-reader Android UI | ~40 screens, ~35,300 lines Compose | direct count |
| DB | 9 tables, 3 views, 13 migrations, **5 triggers** | `data/src/main/sqldelight` |

---

## The theme lever — the finding that reshapes the plan

The adversarial ecosystem review flagged one number as unmeasured and
"the only structural lever that changes the shape of the cost curve." I measured
it: **53.8% of the catalog are thin theme subclasses.**

This clears the >50% bar the reviewer set, which means **the unit of work is the
theme, not the source**:

- Port **`madara` alone → unlocks 295 extensions.**
- Port **`madara` + `mangathemesia` → 440 extensions (32% of the catalog) from 2 implementations.**
- Top 10 themes → 570 extensions (41.7%).
- The remaining 631 bespoke sources are strictly linear, ~1 site per port, forever.

**Sequence the entire catalog roadmap as "port theme → unlock N sites."** Any plan
that counts sources rather than themes will underestimate early reach and
overestimate late reach.

⚠️ **Correction to a claim you may see repeated:** MangaDex's "61 index entries"
are 61 *language variants of one website*, not 3% of the ecosystem. 94.5% of
packages are single-source; the language fan-out lever is exhausted after ~8
sources. **Count websites, never index entries.** MangaDex is still the right
first port — but because it is a clean JSON API with no HTML parsing and no
Cloudflare, making it the cheapest possible runtime smoke test.

---

## Three decisions that gate everything (ADRs required before code)

### ADR-0 — Distribution route ⚠️ **DECIDE FIRST**

This determines what Lane 1 even builds. Getting it wrong late invalidates work
across every lane. **Recommendation: two build targets from one core, gated by a
compile-time flag** (~2–3 engineer-weeks for the split + CI):

- **Track A — App Store build.** Advertised primary purpose is a *local-files and
  self-hosted-server comic reader* (Komga / Kavita / Suwayomi / OPDS). **Zero
  bundled aggregator sources.** This is legally clean — the user supplies the content.
- **Track B — Sideload build** (AltStore/SideStore, or EU alternative marketplace).
  Full dynamic source runtime and the aggregator catalog.

**Do NOT ship one binary with a hidden toggle.** A remote kill-switch that reveals
functionality post-review is a Guideline 2.3.1 "hidden features" violation that
terminates *developer accounts*, not just apps. Both the platform lane and the
policy verifier independently converged on this.

**Reject TestFlight as a primary channel:** builds expire at 90 days, cap 10,000
testers, and external TestFlight still passes Beta App Review under the same
content guidelines. It escapes storefront rules, not content rules.

### ADR-1 — Source runtime: **JavaScriptCore + a Cheerio-equivalent DOM layer**

Survived all three adversarial lenses. Rationale is twofold:

1. **Porting cost dominates**, and Jsoup selector strings + `Element` traversal map
   to Cheerio near-mechanically. Across a four-digit catalog this is the only lever
   that matters.
2. **Policy** (the stronger argument, and one the original analysis missed):
   Guideline 4.7 permits non-embedded "HTML5 and JavaScript mini apps... and
   plug-ins" **by name, and names nothing else.** A standalone WASM interpreter
   executing downloaded bytecode must argue from analogy. WASM (the Aidoku model)
   is both more expensive to port *and* policy-disfavored.

Note JSC's lack of JIT is not a JSC handicap — iOS forbids W^X to all non-WebKit
processes, so a WASM interpreter is equally interpreted. It is interpreter vs
interpreter.

### ADR-2 — Persistence: **GRDB.swift** (not SwiftData)

Not a close call. The schema is SQL-first and SwiftData cannot express **any** of
its four load-bearing properties: the 5 triggers driving sync conflict
resolution, the 3 SQL views, the 3-CTE `getDuplicateLibraryManga` query, and
reactive observation that correctly sees trigger-driven writes. Record this as an
ADR with those four failures enumerated so it is not relitigated in month four.

**Keep the triggers in SQL — do not reimplement them in Swift.** Dropping them
breaks nothing visibly; sync just starts losing writes months later.

---

## ⚠️ Unresolved conflict — needs your decision + verification

The platform lane and the policy verifier **disagree**, and I have not
independently verified either:

| | Platform lane (Lane 6) | Policy verifier |
|---|---|---|
| Can the App Store build have a **dynamic** JS runtime? | **No.** 2.5.2/3.3.2 forbid a downloadable runtime that changes behavior post-review. App Store build must be **statically compiled**. | **Yes.** Guideline 4.7 affirmatively permits JS plug-ins; **Paperback (JS-based) is reportedly on the App Store today**, while Aidoku (WASM) is not. |

Both agree on: zero bundled aggregator sources for Track A, two separate builds,
sideload for the full catalog. They differ only on whether Track A may load
user-supplied source repos dynamically.

**The load-bearing unverified fact:** whether Paperback's *App Store binary*
can actually add arbitrary third-party repos, or whether that capability exists
only in a sideloaded build. The verifier explicitly flagged that it confirmed the
listing and description but **not** the in-app repo capability. **I have not
verified this myself and it should not be treated as settled.**

**Recommended action before ADR-0:** install Paperback from the App Store and
check whether arbitrary repo URLs can be added. That single observation decides
whether Track A is a static reader or a dynamic one — worth ~30 minutes against a
decision that reshapes months of work.

Also unbudgeted if Track A targets the App Store: **4.7.5 age gating** (a local
NSFW toggle does not satisfy "verified or declared age" — Paperback built
account-based gating for this, ~3–5 weeks incl. backend), **4.7.1 content
reporting** (~1–2 weeks), and **4.7.2** which requires *prior Apple permission* to
expose native APIs to non-embedded software — a direct hit on the host-function
bridge design. Add ~5–9 weeks to the Track A path.

---

## Phased roadmap

Waves are ordered by true runtime dependency. Items inside a wave are
file-disjoint and can run concurrently.

### Wave 0 — Decide & de-risk (2–4 weeks) — *no feature code*

- [ ] **ADR-0 distribution** (blocks everything; verify the Paperback question first)
- [ ] **ADR-1 runtime**, **ADR-2 persistence**, ADR-3 min iOS = **17.0**, ADR-4 DI = hand-rolled `AppEnvironment`
- [ ] **SPIKE: `.tachibk` wire format** against a real backup with a byte-level dumper
- [ ] **SPIKE: bridged-DOM vs in-JS Cheerio benchmark** on a real 2 MB / 1,000-chapter page
- [ ] **Submit the MyAnimeList API application** (human-reviewed, unpredictable, cannot be parallelized)
- [ ] **Acquire Mac access** — see "Hard constraint" below
- [ ] Time **three real source ports** end-to-end (one `madara`, one bespoke, one JSON API) to replace estimates with measurements

### Wave 1 — Foundations (parallel; ~10–14 weeks)

- [ ] GRDB schema + migrations 1–13 + **trigger conformance suite first**
- [ ] Domain entity structs, column adapters, repository protocols
- [ ] JSC sandbox: `JSContext` per source + **a second, bridge-free context for nested `eval()`** (see risk R2)
- [ ] Host-function bridge: HTTP, cookie jar, storage — keep the surface minimal, enumerable, and documented as a review artifact
- [ ] Design system + theme tokens; typed router
- [ ] i18n → String Catalogs (parallelizable from day 1)

### Wave 2 — The catalog (theme-first; ~12–18 weeks)

- [ ] **Jsoup-semantics DOM layer** — this is a *port*, not a shim (see risk R1)
- [ ] Selector conformance suite as a **gating** deliverable
- [ ] **Source-ID MD5 parity** — `md5("${name.lowercase()}/$lang/$versionId")`, first 8 bytes BE, sign bit cleared. Test against all 2,016 index entries.
- [ ] MangaDex (JSON API — cheapest smoke test)
- [ ] **`madara` theme → 295 sources**
- [ ] **`mangathemesia` theme → 145 sources**
- [ ] Contributor SDK, TS types, scaffold, hot-reload — justified as *maintainer velocity tooling*, not a community bet

### Wave 3 — Core app (parallel; ~20–30 weeks)

- [ ] Library screen (the densest UI — prototype the pager against a 5,000-item fixture in week 1)
- [ ] Manga detail, Browse, Updates/History/Categories, Settings DSL
- [ ] Reader: decode pipeline → `ZoomablePageCell` → paged + webtoon viewers (**UIKit behind `UIViewControllerRepresentable`**, not SwiftUI)
- [ ] Foreground download pipeline; storage root abstraction
- [ ] MyAnimeList + AniList trackers

### Wave 4 — Migration & platform (~12–18 weeks)

- [ ] **`.tachibk` importer** with exact merge semantics (the highest-risk item in the project)
- [ ] Backup **export** + round-trip acceptance test against real Mihon
- [ ] Background `URLSession` transfer tier; `BGTaskScheduler` refresh
- [ ] Local source over Files.app; libarchive
- [ ] `PrivacyInfo.xcprivacy`, MetricKit, CI

### Deferred to v1.1+

Migration tool (needs a mature source layer or it produces data-loss reports),
Shikimori/Bangumi/Hikka/MangaBaka, Kitsu/MangaUpdates (both require collecting a
plaintext third-party password), enhanced trackers (depend on their sources
shipping), JPEG-XL (instrument first — ImageIO covers real traffic).

---

## Effort

| Lane | Range (eng-wks) | Cost driver |
|---|---|---|
| 1. Source runtime | **45–75** | Jsoup-semantics port; per-source migration; cookie bridge |
| 2. Data & backup | 13–20 | ~All variance is the `.tachibk` importer |
| 3. Reader | 22–32 | No `SubsamplingScaleImageView` equivalent; jetsam |
| 4. UI & navigation | 34–52 | ~40 screens; Library screen; absent SwiftUI primitives |
| 5. Background & storage | 16–24 | Background transfer tier forces idempotent pipeline stages |
| 6. Trackers & platform | 9–14 | OAuth registration calendar time, not code |
| **Total** | **139–217** | ≈2.7–4.2 engineer-years |
| **+ perpetual** | **4–6 /year** | Catalog maintenance at 30 sources; linear; 1 FTE at ~250–300 |

Lane 1 was repriced upward from its own 34–58 estimate by the feasibility
verifier (Jsoup-semantics port + cookie-store bridge + dual-context sandboxing).
Add ~5–9 weeks if Track A targets the App Store.

**Steady-state maintenance is the number that decides whether the project
survives year two, and it sets a hard ceiling on catalog size for any staffing
level.** It is not a risk bullet; it is a line item.

---

## Risk register — blockers only

**R1 — Jsoup's selector dialect is not CSS.** `:matches()` is a **regex**
pseudo-selector in Jsoup but an `:is()` **alias** in Cheerio/css-select — a silent
semantic collision, plus `:containsOwn`, `:matchesOwn`, whitespace-normalized
`:contains`, and differing tree construction. A conformance suite *detects* these;
it does not *fix* them. Budget a Jsoup-semantics port (8–14 wks), not a shim.

**R2 — Nested `eval()` escapes the sandbox.** `JavaScriptEngine.kt:11-25` exposes
`evaluate(script:)` to extensions; sources eval **site-supplied JS** to unpack
obfuscated page URLs. Android isolates this per-call in a fresh QuickJS VM with
zero host functions. On iOS, if a source evals inside its own `JSContext`,
attacker-controlled remote JS inherits **the entire host bridge**. A second,
bridge-free context with a hard timeout is a **v1 requirement, not hardening.**

**R3 — `.tachibk` has no formal specification.** It is kotlinx.serialization's
protobuf dialect defined by scattered Kotlin annotations, with legacy field-number
gaps and a polymorphic sealed-class encoding for `PreferenceValue` that has no
swift-protobuf analogue. Spike it against real backups **before scheduling any
importer work**; budget for a fully hand-written decoder.

**R4 — Source IDs must be bit-exact or every import silently orphans.** Restored
rows carry `source: Long`; if the runtime invents its own IDs, the import reports
success and produces an empty library. Hard requirement on Lane 1, not a preference.

**R5 — iOS jetsam.** No warning, no graceful degradation — the app is killed. A
20,000px webtoon strip is 300+ MB as ARGB8888. **Ban `UIImage(data:)` by lint
rule**; every decode goes through `CGImageSourceCreateThumbnailAtIndex` with an
explicit max pixel size. Test on the oldest supported device — the simulator has
no jetsam.

**R6 — Cloudflare clearance may not transfer.** ⚠️ *Commonly misdiagnosed as JA3
fingerprinting.* The real mechanism is **cookie-store unification**:
`AndroidCookieJar.kt:10` backs OkHttp's jar with `android.webkit.CookieManager`,
so WebView and HTTP client share **one store by construction** — which is why a
bare `chain.proceed()` succeeds right after the WebView solve. iOS has no unified
store; `WKWebsiteDataStore.httpCookieStore` and `HTTPCookieStorage` are separate,
and WKHTTPCookieStore is async and racy. Budget explicit bidirectional bridging
with an observer. (Mihon already crosses a Chromium↔OkHttp fingerprint boundary
successfully, so JA3 is overstated.)

**R7 — Downloads do not survive backgrounding in any recognizable form.** The
downloader is a *pipeline* (page list → image URL → bytes → MIME sniff → split →
ComicInfo → CBZ), and only raw byte transfer survives suspension; background
sessions reject `dataTask`. Pre-resolve page lists eagerly while foregrounded and
show an honest state ("12 of 340 chapters ready to continue in background")
instead of a progress bar that silently freezes.

**R8 — Scheduled library auto-update is not deliverable.** `BGTaskScheduler` is
opportunistic and never fires with Background App Refresh off or Low Power Mode
on. Reframe: foreground refresh on app open is the primary path, background is an
unadvertised bonus, and the interval setting is relabelled a *minimum*. Add a
diagnostics row showing the last successful background run — this converts an
invisible platform limit into an understandable one and prevents "the app is
broken" reports.

**R9 — App Store content exposure (Track A only).** 389 of 1,367 packages are
NSFW-flagged. Guideline 1.1.6/1.2 exposure — and drawn-minor content is an
instant, non-negotiable *account termination*, not a rejection. Track A must have
**no mechanism whatsoever** to reach those sources.

---

## The zero-cost path (verified July 2026)

Full build, no Mac purchase, nothing beyond the already-owned developer account:

| Need | Free option | Limit |
|---|---|---|
| Compile + test **platform-agnostic Swift** locally | Official **Swift toolchain for Windows** (6.3.2 stable; Foundation, XCTest, SPM, VS Code extension; Windows workgroup since Jan 2026) | No Apple frameworks — no UIKit/SwiftUI/JavaScriptCore |
| Compile + test **iOS SDK** code | **GitHub Actions macOS runners — free and unlimited on public repos**, Apple Silicon included | 6 h/job, concurrency caps, fair use. *Private repos are 10× billed — the repo must be public* |
| Real-device testing | CI → TestFlight → **your iPad** | Slow round-trip; real jetsam, unlike the simulator |
| Xcode, Swift, GRDB, Nuke, libarchive | Free / open source | — |

**What this buys, and what it does not.** Everything headless — domain entities
and flag algebra, the `.tachibk` protobuf decoder, source-ID MD5 parity, chapter
parsing and sort, filter serialization, `FetchInterval` arithmetic, repository
logic behind protocols — is developable in a **fast local loop on Windows** and is
roughly half the project. What it does not buy is **interactive UI iteration**:
no simulator, no SwiftUI previews, no interactive debugger. Every UI change
becomes push → wait → TestFlight → iPad.

**Therefore the architecture is the cost lever.** Structure the app as a
multi-module SPM package with a **strict rule: the core modules import no Apple
framework.** That is good design independently — it is what makes the domain
logic unit-testable without a simulator — but here it also decides how much of
the project you can build for free and how fast the loop is. Push Apple-framework
dependencies (JavaScriptCore, GRDB, UIKit, SwiftUI) behind protocols defined in
the platform-agnostic core, with the concrete implementations in thin outer
modules that only CI compiles.

Verify early rather than assume: confirm which dependencies actually build on the
Windows toolchain. Keeping the repository layer behind protocols sidesteps the
question for domain tests entirely.

**Sequencing under the free path:** Waves 0–2 (source-runtime logic, data layer,
backup importer, trackers) are largely headless — do them free. Wave 3 (reader
and UI) is where the absent simulator stops being an inconvenience and starts
costing more in wasted round-trips than a refurbished Mac mini costs outright.
Buy the Mac when the UI work starts, not before — the free path defers that
purchase by months, it does not remove it.

**One caveat:** free unlimited CI requires the repo to be **public**. Mihon is
open source, so a public port is consistent with its licence (Apache 2.0 — retain
attribution), and it matches how this ecosystem already operates. But it does mean
the source-runtime strategy is developed in the open.

### Verified July 2026 — the zero-Mac pipeline holds end to end

A 4-lane verification (signing / CI / distribution / dev-loop) confirmed **no
hard Mac dependency exists in the ship path**. What survives, with the one place
it genuinely degrades called out:

- **Signing — solved, no Mac (`works-without-mac`).** Apple's "make a CSR in
  Keychain Access" step is a convention, not a requirement. Use **fastlane
  `match`** on the macOS runner, authenticated by an **App Store Connect API key
  (.p8)** — it generates the key, CSR, certificate, and profiles itself and stores
  them encrypted in a **separate private repo**. Two gotchas: the ASC key must be a
  **Team Key with the Admin role** (App Manager cannot touch certificates), and do
  **not** use `xcodebuild -allowProvisioningUpdates` automatic signing on ephemeral
  runners — it burns the 2-cert limit and fails. Use manual signing against the
  match profiles.
- **Device testing — no UDID, no registration.** TestFlight distribution does not
  use UDID provisioning. Add your Apple ID as an internal tester in the web UI,
  install TestFlight on the iPad, done.
- **Upload — `xcrun altool`/`upload_to_testflight` on the runner** with the same
  .p8. Transporter is macOS-only *and* now requires Windows 11 (you are on
  Windows 10) — irrelevant, because the upload happens on the runner, not locally.
- **Xcode Cloud — unreachable, drop it.** Its 25 free hours/month cannot be
  bootstrapped without configuring the first workflow in Xcode on a Mac (the ASC
  API exposes `ciProducts` as read-only). GitHub Actions public-repo runners are
  strictly better anyway (uncapped vs 25 h). **Remove Xcode Cloud from the plan.**
- **Project file — do not hand-maintain `.xcodeproj`.** You cannot open Xcode to
  fix a setting. Generate the project on CI with **XcodeGen or Tuist** from a
  checked-in manifest, or drive an SPM-only build. Decide this at scaffold time.

**The one real degradation — reader performance work (`works-with-caveats`).**
Everything above makes *building and shipping* Mac-free. What CI cannot give you
is **interactive UI iteration and on-device profiling**: no SwiftUI previews, no
interactive simulator, no interactive debugger, no hot reload, and — the sharp
one — **no Instruments**. Time Profiler, Animation Hitches, Allocations, and
jetsam/memory-pressure analysis are all Xcode-only. MetricKit gives *next-day
aggregate* hitch rates from TestFlight (detects a regression, does not localize
it). For a high-performance reader tuning 120 Hz scroll and jetsam behaviour on
huge images (R5), this is the point where the toolchain goes from **"slow" to
"partly blind."** Reader profiling is the one task that genuinely wants a Mac —
which is exactly Wave 3, and exactly where the plan already says to buy one.

## Hard constraint — you are on Windows

Swift, specs, plans, and headless tests can be authored here. **Builds, the
simulator, signing, and the entire reader lane cannot.** CI (GitHub Actions
`macos-15`) covers headless network/persistence work, but a CI round-trip per
SwiftUI iteration roughly **doubles any UI-shaped estimate**.

**Acquire real Mac access before Wave 3.** Priced July 2026:

| Option | Cost | Verdict |
|---|---|---|
| **Refurb M4 Mac mini, 16 GB** | **~$509 one-time** | **Recommended.** Break-even vs cloud ≈ 4 months |
| New M4 Mac mini, 16 GB/512 GB | $799 | Base 256 GB model discontinued May 2026; price rose from $599 |
| MacStadium M4, 16 GB | $119/mo | Real Apple hardware; sensible for a trial or a parallel CI box |
| AWS EC2 Mac | $631–1,418/mo | Only if already standardized on AWS (24 h min. allocation) |
| GitHub Actions `macos` runner | $0.062/min ($3.72/h); free on public repos | CI only — fine through Wave 2, cannot replace a simulator |
| **macOS VM / Docker on this PC** | — | **Rejected — see below** |

Against a 2.7–4.2 engineer-year project, buying is decisively cheaper than renting.
Do **not** buy an 8 GB machine: Xcode 16+ requires 16 GB Apple Silicon for
predictive completion, and 8 GB with Xcode + simulator + this app is a false economy.

**Assets already in hand:** a paid Apple Developer Program membership and an
iPad. Both matter more than they look.

**Real-device testing without owning a Mac.** GitHub Actions' macOS runner can
build, sign, and upload to TestFlight with an App Store Connect API key; the
build then installs on the iPad through the TestFlight app. So real-hardware
verification — including the jetsam behavior the simulator cannot show — is
available from day one, at the cost of a slow CI round-trip per build. This makes
the "no Mac until Wave 3" sequencing genuinely workable rather than a gamble.
Still do the throwaway TestFlight upload in week 3, per Lane 6, to flush out
signing blockers before they surface at week 12.

**The iPad is a test device and a target form factor, not a dev machine.** Xcode
runs only on macOS; Swift Playgrounds cannot carry this project (custom build
settings, an SQLite C library, a libarchive XCFramework, UIKit representables).
But for a *manga reader*, iPad is arguably the best reading surface there is —
large display, natural two-page spreads. Lane 4 currently scopes iPad adaptivity
as an M-sized afterthought; **consider promoting iPad to a first-class v1 target**,
which also strengthens the Track A App Store framing (a polished local-files and
self-hosted reader is a more convincing app on iPad than on iPhone).

**Why macOS in a VM or Docker is rejected — two independent reasons.**
*Legal:* Apple's macOS SLA §2.B ties the right to install **and to virtualize** to
Apple-branded hardware; running it on a Windows PC breaches the licence, and
circumventing Apple's hardware checks implicates the DMCA's anti-circumvention
provisions. That matters more here than for a hobby project, because the endpoint
is shipping under an Apple Developer Program agreement on an account the plan
already flags as terminable (R9). *Practical:* a QEMU/KVM macOS guest has no Metal
passthrough, so the iOS Simulator is unusably slow — and the simulator is precisely
the surface Wave 3 lives on. Docker-OSX also needs a Linux/KVM host, so on Windows
it nests inside WSL2 and is slower still.

**Buying signal for cloud Macs:** legality depends on the provider running *real
Apple hardware* (AWS, MacStadium, and Scaleway rack actual Mac minis). Providers
advertising "virtualized macOS" at $25–55/mo are usually not on Apple hardware and
inherit the same licence problem.

---

## What I did not verify

Stated plainly so it is not mistaken for established fact:

1. **Paperback's App Store repo capability** — the load-bearing fact in the ADR-0
   conflict. Web-derived from a subagent; not independently confirmed.
2. **Effort estimates are estimates.** The three timed real ports in Wave 0 exist
   to replace the two most load-bearing numbers (per-source cost, maintenance run
   rate) with measurements.
3. **Per-source cost** — loaded figures of ~3–5h themed / ~8–25h bespoke include
   live-site verification and fixture capture, but are unvalidated.
4. **External contributor inflow is assumed to be zero.** Keiyoushi authors have a
   live disincentive to dual-target a sideloaded app with no users. If no
   contributor-bootstrap plan exists, cut v1 to 10–15 sources and say so.

---

## Next actions

1. **Verify the Paperback repo question**, then decide **ADR-0**. Everything waits on this.
2. Sign off (or push back on) ADR-1 JavaScriptCore, ADR-2 GRDB, ADR-3 iOS 17.
3. `git init` this repo and commit the scaffold + this plan.
4. Add the Mihon source under `android/` as read-only reference.
5. Submit the MyAnimeList API application — calendar time starts now.
6. Run Wave 0's two spikes and the three timed ports before committing to a schedule.
