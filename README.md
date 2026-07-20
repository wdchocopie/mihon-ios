# Mihon → iOS

A native Swift/SwiftUI port of [Mihon](https://github.com/mihonapp/mihon) (the
maintained Tachiyomi fork). Early scaffold — see
[`docs/plans/2026-07-19-mihon-ios-port.md`](docs/plans/2026-07-19-mihon-ios-port.md)
for the full plan and [`AGENTS.md`](AGENTS.md) for the working contract.

> Ported under Mihon's Apache-2.0 licence; attribution retained. The Android
> source is the behavioral spec, kept out of tree under `android/`.

## Module architecture

The one load-bearing rule: **the platform-agnostic core imports no Apple
framework.** That is what lets ~half the project be built and tested on Windows
with `swift test` — no Mac, no CI round-trip. Apple-framework code sits in thin
outer modules behind protocols defined in the core, guarded by `#if canImport`.

| Module | Tier | Builds on | Purpose |
|---|---|---|---|
| `MihonCore` | agnostic | **Windows** + CI | Domain models, `Source` protocol, repository protocols, `SourceID` (MD5 parity) |
| `MihonBackup` | agnostic | **Windows** + CI | `.tachibk` decode (pure protobuf bytes) |
| `MihonSources` | Apple | CI only | JavaScriptCore source runtime (ADR-1) |
| `MihonData` | Apple | CI only | GRDB-backed repositories (ADR-2) |
| `MihonUI` | Apple | CI only | SwiftUI screens |
| `App/` | Apple | CI only | iOS app entry (generated Xcode target) |

## Developing

**Locally on Windows** (or any Swift platform) — Swift 6.3.3 toolchain:
```
swift build       # first run fetches swift-crypto (~2.5 min)
swift test        # builds all modules, runs the core + backup tests
```
The Apple modules compile to empty via `#if canImport(...)`, so this stays green
everywhere. Open a **fresh terminal** after installing Swift so `SDKROOT` and
`PATH` are picked up; if `swift build` reports *"unable to load standard
library"*, `SDKROOT` isn't set — point it at
`…\Programs\Swift\Platforms\<ver>\Windows.platform\Developer\SDKs\Windows.sdk`.
(A harmless symlink warning on `.build\debug` appears unless Windows Developer
Mode is on — the build still completes.)

Verified 2026-07-20: builds and tests green locally on Windows **and** on the
Linux CI. 10 tests pass, 1 (`SourceID` golden vectors) intentionally skipped
pending real Mihon IDs.

**iOS builds** happen on GitHub Actions macOS runners (free on this public repo):
- `core-tests.yml` — Linux build + test, every push (the boundary gate).
- `ios-build.yml` — build, sign via fastlane `match`, upload to TestFlight
  (manual trigger; see its header for the one-time secret setup, all doable
  from Windows). Install on-device through the TestFlight app on an iPad/iPhone.

The Xcode project is **generated** from `project.yml` (`xcodegen generate`) on
CI and is gitignored — edit `project.yml`, never a `.xcodeproj`.

## Status of this scaffold

**Compiled and tested green on Windows (Swift 6.3.3) and Linux CI.** `SourceID`
is a genuine, tested vertical slice; everything else is a boundary-correct stub
with `TODO(port)` markers pointing at the Kotlin source and the relevant plan
risk (R1–R9). The module boundary is verified: an accidental Apple-framework
import in a core module would break the Linux CI build.
