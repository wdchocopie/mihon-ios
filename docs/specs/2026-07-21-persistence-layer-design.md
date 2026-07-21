# Persistence Layer — Design Spec

**Status:** Implemented (GRDB-agnostic core); live GRDB tier deferred (CI-gated)
**Objective:** Port Mihon's `:data` layer — the SQLite schema, column adapters,
and row→entity mappers — to `MihonData`, honoring ADR-2 (GRDB / SQL triggers).
**Android source:** `data/src/main/sqldelight/tachiyomi/**` (schema) and
`data/src/main/java/tachiyomi/data/**` (adapters, mappers, repository impls).
**Hard invariants:** the 7 triggers and version-counter semantics must be exact;
the genre `", "` separator must round-trip identically (backup boundary).

## The gating discovery: GRDB cannot build on Windows

ADR-2 chose GRDB.swift. A probe showed GRDB **cannot be built — or even
resolved — on the Windows Swift toolchain**: its `swift build` fails at checkout
with `unable to create symlink Tests/CustomSQLite/GRDB: Permission denied` (a
Windows symlink-privilege limit that `core.symlinks=false` did not fix, because
SPM's checkout ignores it), and GRDB additionally needs a system SQLite that
Windows Swift does not ship. GRDB officially supports Apple + Linux, not Windows.

**Consequence — a two-tier split:**

| Tier | Contents | Builds / tests on |
|---|---|---|
| **`MihonData`** (this spec) | schema DDL, column adapters, mappers — no GRDB | **Windows** (local) + Linux CI |
| **`MihonDataGRDB`** (follow-up) | GRDB repository impls, live DB, trigger-conformance | Linux CI + Apple only |

This keeps the bit-exact, high-risk content (the schema with its 7 triggers, the
`", "` genre join, the version-counter SQL, the entity mappers) in the tier that
is **fully verifiable on the free local loop**. The GRDB execution tier is
mechanical once these exist, and its correctness gate is the Linux CI — which
must be set up with `libsqlite3-dev` + a platform-scoped GRDB dependency.

## Design (this tier)

- **`MihonSchema`** — the complete baseline DDL as one SQL script (the current
  v13 schema a fresh iOS DB creates): 9 tables + indexes, **7 triggers** (three
  on `mangas`, two on `chapters`, one on `mangas_categories`, one system-category
  guard), 3 views, and the system-category seed row. Exposes `tableNames`,
  `triggerNames`, `viewNames` for verification. SQLDelight `AS` type hints are
  compile-time only → plain `TEXT`/`INTEGER`/`BLOB`.
- **`ColumnAdapters`** — `StringListColumnAdapter` (genre, `", "`),
  `UpdateStrategyColumnAdapter` (ordinal, unknown→ALWAYS_UPDATE),
  `MemoColumnAdapter` (JSONValue ⟷ JSON bytes), `BooleanColumnAdapter`,
  `DateColumnAdapter` (identity — entities already store epoch millis).
- **`Mappers`** — `mapManga/mapChapter/mapCategory/mapHistory/mapTrack`:
  row-columns → domain entities, mirroring the Kotlin `*Mapper.kt` field routing
  (`lastUpdate ?? 0`, `calculateInterval → fetchInterval`, etc.).

## Decisions settled here

- **Two-tier (agnostic core + GRDB tier), driven by the Windows/GRDB reality.**
  Does not override ADR-2 (GRDB remains the engine); it sequences it.
- **Fresh-install schema, not the 13 Android migrations.** iOS installs start at
  the current schema and import user data via `.tachibk` (the backup layer), not
  by migrating a raw Android SQLite file. The `.sqm` migration history is
  therefore reference-only for the iOS port.

## Deferred (follow-up increments)

- `MihonDataGRDB`: GRDB `DatabaseMigrator` wiring the baseline DDL, repository
  implementations of the `MihonCore` protocols, and `ValueObservation` for the
  `Flow`→`AsyncStream` reactive reads.
- **Trigger-conformance suite** — proving the version counters increment only
  when `is_syncing = 0` and specific fields change. Requires a live SQLite engine
  → runs on Linux CI.
- CI: install `libsqlite3-dev`, add GRDB as a platform-scoped dependency, run the
  GRDB tier's tests on the Linux runner.
- `mapLibraryManga` and the other view read-models (need the expanded
  `LibraryManga` and the view queries).

---
No paired plan doc — the design investigation (GRDB probe + full schema
extraction) is captured here; the master plan's Wave-1 persistence items are the
parent.
