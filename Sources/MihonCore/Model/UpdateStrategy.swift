import Foundation

/// Per-manga library-update strategy. Mirrors Mihon's `UpdateStrategy`
/// (`source-api/.../model/UpdateStrategy.kt`). Persisted as an Int in the
/// `mangas.update_strategy` column — raw values must not change.
public enum UpdateStrategy: Int, Sendable, Codable, CaseIterable {
    /// Included in library updates unless excluded by another restriction.
    case alwaysUpdate = 0
    /// Skipped during library updates (e.g. known-finished single-chapter series).
    case onlyFetchOnce = 1
}
