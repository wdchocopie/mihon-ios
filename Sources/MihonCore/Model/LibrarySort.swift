import Foundation

/// Library sort packed into a `Category.flags: Int64`. Ported from
/// `library/model/LibrarySortMode.kt` + `Flag.kt`.
///
/// Layout: **Type = bits 2–5 (mask 0b00111100), Direction = bit 6 (0b01000000)**.
/// ⚠️ `Ascending` is the SET bit (0b01000000); `Descending` is 0 — inverted from
/// intuition. Bits 0–1 and 7+ are legacy/unused and must be masked off.
public struct LibrarySort: Sendable, Hashable, Codable {

    public enum SortType: Int64, Sendable, Hashable, Codable, CaseIterable {
        case alphabetical    = 0b00000000
        case lastRead        = 0b00000100
        case lastUpdate      = 0b00001000
        case unreadCount     = 0b00001100
        case totalChapters   = 0b00010000
        case latestChapter   = 0b00010100
        case chapterFetchDate = 0b00011000
        case dateAdded       = 0b00011100
        case trackerMean     = 0b00100000
        case random          = 0b00111100   // == the full type mask

        public static let mask: Int64 = 0b00111100
    }

    public enum Direction: Int64, Sendable, Hashable, Codable, CaseIterable {
        case descending = 0b00000000
        case ascending  = 0b01000000

        public static let mask: Int64 = 0b01000000
    }

    public var type: SortType
    public var direction: Direction

    public init(type: SortType, direction: Direction) {
        self.type = type; self.direction = direction
    }

    public static let `default` = LibrarySort(type: .alphabetical, direction: .ascending)

    /// The combined masked value (`type + direction`). Because the two masks are
    /// disjoint this equals `type.rawValue | direction.rawValue`.
    public var flag: Int64 { type.rawValue | direction.rawValue }

    public static let mask: Int64 = SortType.mask | Direction.mask

    public var isAscending: Bool { direction == .ascending }

    /// Decode from a `Category.flags` Long. Unknown bits → defaults; nil → default.
    public static func from(flag: Int64?) -> LibrarySort {
        guard let flag else { return .default }
        let type = SortType.allCases.first { $0.rawValue == (flag & SortType.mask) } ?? .alphabetical
        let dir = Direction.allCases.first { $0.rawValue == (flag & Direction.mask) } ?? .ascending
        return LibrarySort(type: type, direction: dir)
    }

    /// Apply this sort onto an existing flags Long (read-modify-write, preserving
    /// non-sort bits) — mirrors the Kotlin `Long.plus(Flag)` operator.
    public func applied(to base: Int64) -> Int64 {
        (base & ~LibrarySort.mask) | (flag & LibrarySort.mask)
    }

    // MARK: String form "TYPE,DIRECTION" (pref / .tachibk)

    private static let typeNames: [(SortType, String)] = [
        (.alphabetical, "ALPHABETICAL"), (.lastRead, "LAST_READ"),
        (.lastUpdate, "LAST_MANGA_UPDATE"),   // ⚠️ name trap: not "LAST_UPDATE"
        (.unreadCount, "UNREAD_COUNT"), (.totalChapters, "TOTAL_CHAPTERS"),
        (.latestChapter, "LATEST_CHAPTER"), (.chapterFetchDate, "CHAPTER_FETCH_DATE"),
        (.dateAdded, "DATE_ADDED"), (.trackerMean, "TRACKER_MEAN"), (.random, "RANDOM"),
    ]

    public func serialize() -> String {
        let name = LibrarySort.typeNames.first { $0.0 == type }?.1 ?? "ALPHABETICAL"
        return "\(name),\(direction == .ascending ? "ASCENDING" : "DESCENDING")"
    }

    public static func deserialize(_ serialized: String) -> LibrarySort {
        if serialized.isEmpty { return .default }
        let parts = serialized.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else { return .default }
        let type = typeNames.first { $0.1 == parts[0] }?.0 ?? .alphabetical
        let dir: Direction = parts[1] == "ASCENDING" ? .ascending : .descending
        return LibrarySort(type: type, direction: dir)
    }
}

/// Library display mode, ported from `library/model/LibraryDisplayMode.kt`.
/// Persisted as a STRING (not bit-packed). Unknown string → default (compactGrid).
public enum LibraryDisplayMode: String, Sendable, Hashable, Codable, CaseIterable {
    case comfortableGrid = "COMFORTABLE_GRID"
    case compactGrid = "COMPACT_GRID"
    case coverOnlyGrid = "COVER_ONLY_GRID"
    case list = "LIST"

    public static let `default`: LibraryDisplayMode = .compactGrid

    public static func deserialize(_ serialized: String) -> LibraryDisplayMode {
        LibraryDisplayMode(rawValue: serialized) ?? .default
    }

    public func serialize() -> String { rawValue }
}
