import Foundation
import MihonCore

// GRDB-backed persistence (ADR-2). GRDB is added as a package dependency only
// after the Wave-0 check confirms it builds cleanly on the Windows toolchain
// (plan: "verify which dependencies build on Windows"). Until then this module
// carries no external dependency, and its body is guarded so the package builds
// on every platform. GRDB is SQLite-based (SQLite is cross-platform), so it may
// well build on Windows — but that is to be verified, not assumed.
#if canImport(GRDB)
import GRDB

// TODO(port): GRDBMangaRepository: MangaRepository, backed by a DatabasePool.
// Keep the 5 SQLite TRIGGERS and 3 views in SQL (do NOT reimplement in Swift):
// they drive the version/last_modified_at sync semantics and a naive port that
// drops them corrupts sync silently (plan R / ADR-2). Land the trigger
// conformance test suite BEFORE any repository code.

#else

/// Stand-in so the module always has a symbol. Replaced by the GRDB-backed
/// repositories once the dependency is wired in.
public enum MihonDataPlaceholder {
    public static let pendingGRDB = true
}

#endif
