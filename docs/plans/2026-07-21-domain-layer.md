# Domain Layer — Implementation Plan

**Goal:** Port Mihon's `:domain` layer to `MihonCore` as platform-agnostic Swift
(builds + tests on Windows), bit-exact where it crosses the backup/DB boundary.
**Spec basis:** `.claude/plans/domain-layer-context.md` (verbatim schema) +
Mihon source. **Branch:** `feat/domain-layer` → PR into `main`.
**Status:** proposed → review → execute → review.

## Scope

**In v1:** entity value types (Manga+MangaUpdate, Chapter+ChapterUpdate, Category,
Track, History) with exact defaults; the `chapterFlags` algebra + TriState; the
Category `LibrarySort` flag algebra + LibraryDisplayMode; ChapterRecognition;
ChapterSort; FetchInterval (pure algorithm); SetMangaChapterFlags logic;
ShouldUpdateDbChapter; expanded repository protocols. Golden-vector tests for the
bit-exact pieces.

**Deferred (follow-up):** the `WithRelations` read-model types, the thin
delegation interactors, GetNextChapters/ReorderCategory (need repo wiring), the
locale-collator exactness for alphabet sort (v1 uses `localizedStandardCompare`),
Foundation-free date/zone plumbing for FetchInterval's edge (v1 tests the pure
core with injected day-deltas).

## Design decisions

1. **Entities are immutable structs** with a memberwise-friendly init carrying the
   exact Kotlin defaults (id/source = -1 sentinels, Chapter.version = 1,
   favorite = false, notes = "" non-optional, chapterFlags = 0).
2. **Flags stay as `Int64` values in place** (compared against constants, never
   shifted down). One `setFlag(_:mask:)` primitive: `(self & ~mask) | (flag & mask)`
   with explicit parens — the single most-reused bit op.
3. **`TriState` and sort/display are typed enums** for the API, but encode/decode
   go through the raw `Int64` constants so the on-disk representation is identical.
4. **ChapterRecognition ported verbatim**, with the Swift `Double(".5")`→nil fix
   and match-materialization (no lazy Sequence).
5. **ChapterSort replicates each branch literally** (SOURCE inverted) and uses a
   **stable** sort helper (index tiebreak) since Swift's sort isn't stable.
6. **FetchInterval splits pure-vs-edge:** the windowing/median/backoff/clamp math
   is pure and fully tested; the timezone/day-truncation is a thin injectable seam.
7. **No Apple-only framework** (UIKit/SwiftUI/JavaScriptCore/CoreData/CoreGraphics)
   — but **`import Foundation` is allowed** (cross-platform; already used; needed
   for NSRegularExpression, Calendar, localizedStandardCompare). The Linux CI
   boundary gate is the real enforcer.

## Waves & file ownership (disjoint — no two builders share a file)

### Wave 1 — Shared contract (built + compiled green FIRST, by the orchestrator)

The entity types + flag constants are what every logic file imports, and they hold
the highest-risk bit-exact constants, so they are pinned before fan-out.

- Add: `Sources/MihonCore/Model/Manga.swift` (Manga, MangaUpdate, MangaStatus reuse, UpdateStrategy reuse, chapterFlags constants + getters + setFlag + sortDescending)
- Add: `Sources/MihonCore/Model/MangaFlags.swift` (TriState, ChapterSortMode/Direction/DisplayMode enums + encode/decode, applyFilter)
- Add: `Sources/MihonCore/Model/Chapter.swift` (Chapter, ChapterUpdate, isRecognizedNumber, copyFrom)
- Add: `Sources/MihonCore/Model/Category.swift` (Category)
- Add: `Sources/MihonCore/Model/LibrarySort.swift` (LibrarySort Type/Direction + Flag packing + LibraryDisplayMode + serialize/deserialize)
- Add: `Sources/MihonCore/Model/Track.swift`, `Sources/MihonCore/Model/History.swift`
- Edit: `Sources/MihonCore/Persistence/Repositories.swift` (expand protocols + ancillary placeholder types)
- Note: the current minimal `Manga`/`SManga` overlap — reconcile: keep `SManga`
  (source model) as-is; the new `Manga` is the library/domain entity.

**Verification:** `swift build` green; the flag constants compile.

### Wave 2 — Logic (4 parallel builders, each owns 1 source + 1 test file)

Each reads the context pack §§ for its piece and the pinned Wave-1 API. No builder
touches another's files or any Wave-1 file.

- **Builder A — ChapterRecognition:** `Domain/ChapterRecognition.swift` + `Tests/MihonCoreTests/ChapterRecognitionTests.swift`
- **Builder B — ChapterSort:** `Domain/ChapterSort.swift` (+ stable-sort helper) + `Tests/MihonCoreTests/ChapterSortTests.swift`
- **Builder C — FetchInterval:** `Domain/FetchInterval.swift` (pure core) + `Tests/MihonCoreTests/FetchIntervalTests.swift`
- **Builder D — Flag mutation:** `Domain/SetMangaChapterFlags.swift` + `Domain/ShouldUpdateDbChapter.swift` + `Tests/MihonCoreTests/MangaFlagsTests.swift`

**Verification per builder:** its test file passes `swift test --filter <Suite>`.

### Wave 3 — Golden vectors + integration (orchestrator)

- Generate independent **golden vectors** (Python, like SourceID) for: chapterFlags
  pack/unpack round-trips; LibrarySort flag↔string; ChapterRecognition over a
  corpus of real chapter titles; FetchInterval on hand-computed day-delta inputs.
- Add `Tests/MihonCoreTests/GoldenVectorTests.swift` asserting Swift == the
  independently-computed expected values.
- `swift test` full suite green locally + Linux CI.

## Risk register (bit-exact traps — from the extraction)

- **B1** chapterFlags default 0 = descending source order; direction is bit 0 clear.
- **B2** TriState persisted bits (0x2/0x4…) ≠ enum ordinals (1/2); 0x6 combo → DISABLED.
- **B3** LibrarySort Ascending = SET bit (0x40); Descending = 0. Name trap LastUpdate↔"LAST_MANGA_UPDATE".
- **B4** `Double(".5")` = nil in Swift; ChapterRecognition must handle leading-dot.
- **B5** ChapterSort SOURCE case inverted; needs stable sort.
- **B6** FetchInterval median index `(size-1)/2`, window `<=8→3`, negative-interval sentinel, `floorDiv`.
- **B7** Chapter.version defaults to 1, not 0; id/source = -1 sentinels.

## Verification strategy

The non-circular proof is **Mihon's own upstream test vectors** (produced by the
real Kotlin engine — a Python re-impl would be a third regex/collation engine and
could agree with neither spec nor impl). Ported verbatim into `GoldenVectorTests`
from `ChapterRecognitionTest.kt` (~50), `LibraryFlagsTest.kt`, and
`FetchIntervalTest.kt`, plus hand-authored SetMangaChapterFlags transition
vectors. Then an adversarial review pass over the diff hunts for divergence.

## Review resolutions (applied 2026-07-21)

A 3-lens adversarial review ran before this build. Verdicts: all
`ready-with-fixes` (no rework). Folded in:
- **Blocker (extraction bug):** `unwanted` regex was missing `volume` — fixed in
  the context pack.
- **Blocker (compile):** an existing `struct Manga` stub in `Repositories.swift`
  collides with the new entity → Wave 1 deletes the stub.
- **Blocker (contradiction):** Foundation ban relaxed (Decision 7 above).
- **High:** NSRegularExpression (not Swift Regex — lookbehind); `memo` pinned as a
  shared `JSONValue` in Wave 1 (Builder D needs it Equatable); golden = upstream
  vectors, not Python.
- **Medium/Low:** exact `Double("0"+d)` fix, stable index-tiebreak, NaN-safe Double
  compare, `floorDiv` helper, order-preserving `distinct`, History defaults,
  COMPLETED=2, ChapterUpdate single home, alphabet collation not golden-vectored.

All corrections live in the context pack's "REVIEW CORRECTIONS" header, which the
builders read first.

## Review-all resolutions (Phase 4, applied 2026-07-21)

After the build, a 3-lens adversarial verification traced the Swift against the
Kotlin for divergences the (ASCII-only) upstream golden vectors miss. **Fixed**
(each with a regression test in `DomainRegressionTests`):
- **ChapterRecognition `\b`/`\s`** were ICU-Unicode-aware but Java's are
  ASCII-only — a **non-ASCII manga title** (the norm) mis-parsed volume tags and
  NBSP-glued keywords. Pinned to ASCII semantics.
- **ChapterSort alphabetical** used `localizedStandardCompare` (numeric runs:
  "Chapter 2" before "Chapter 10") — Kotlin's `Collator(PRIMARY)` is lexical
  ("Chapter 10" first). Replaced with a fold-then-lexical compare (also
  cross-platform-deterministic, fixing the Linux-vs-Apple collation concern).
- **JSONValue** collapsed all numbers to `Double`, losing large-integer precision
  and making `1` == `1.0` — which broke the `ShouldUpdateDbChapter` memo
  dirty-check (missed refreshes). Added `case int(Int64)` (kotlinx content-equality parity).
- **FetchInterval.calculateNextUpdate** used the DST offset at the target date
  instead of the reference instant's fixed offset (off-by-an-hour in non-UTC
  zones across a DST boundary). Corrected to the fixed offset.

**Deferred as documented micro-divergences** (rare inputs, diminishing returns):
- Numbers outside `Double` range in `memo` (e.g. `1e400`) — astronomically rare;
  the `.int` case covers all realistic values. Noted in `JSONValue`.
- `String.trim()` control-char set (U+001C–U+001F) — never adjacent to the parsed
  number in practice.
- `SManga.status` as a closed enum vs Kotlin's open `Int` — SManga is a transient
  source model, not persisted; unknown codes are out of v1 scope.
