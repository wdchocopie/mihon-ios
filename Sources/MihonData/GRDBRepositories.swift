import Foundation

// GRDB-backed repository implementations — the live SQLite execution tier — are
// a **CI-gated follow-up**, deliberately NOT in this module yet.
//
// Why: GRDB cannot build on the Windows dev toolchain — its checkout fails on a
// symlink permission error, and it needs a system SQLite that Windows Swift does
// not ship. So the GRDB tier can only be built/tested on the Linux CI runner (or
// Apple), where a `libsqlite3-dev` + GRDB pipeline must be set up. Building it
// here would be entirely blind (no local compile), which fails the correctness bar.
//
// This module (`MihonData`) therefore ships the **GRDB-agnostic core** that IS
// fully Windows-testable and holds all the bit-exact, backup-boundary-critical
// content:
//   - `MihonSchema`      — the complete baseline DDL (9 tables, 7 triggers, 3 views)
//   - `ColumnAdapters`   — genre ", " join, updateStrategy, memo, boolean, date
//   - `Mappers`          — row-columns → domain entities
//
// The follow-up adds `MihonDataGRDB` (a separate target with a platform-scoped
// GRDB dependency) implementing the `MihonCore` repository protocols against a
// real database, plus the trigger-conformance suite that proves the version
// counters increment correctly — which can only run against a live SQLite engine.
public enum MihonDataInfo {
    public static let liveDatabaseTier = "deferred — see GRDBRepositories.swift"
}
