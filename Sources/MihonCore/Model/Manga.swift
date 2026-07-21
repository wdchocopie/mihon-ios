import Foundation

/// The library/catalog manga **domain** entity (distinct from `SManga`, the
/// source model). Ported from `domain/.../manga/model/Manga.kt` as a Swift value
/// type. Holds the `chapterFlags` bitfield and its accessors.
///
/// Bit-exactness: `chapterFlags`/`viewerFlags` are `Int64` that cross the
/// `.tachibk`/DB boundary. The flag constants and the `setFlag` primitive must be
/// reproduced exactly (see the context pack). Default `chapterFlags = 0` ⇒
/// source-order sort with the direction bit clear ⇒ natural ascending source order.
public struct Manga: Sendable, Hashable, Identifiable, Codable {
    public var id: Int64
    public var source: Int64
    public var favorite: Bool
    public var lastUpdate: Int64
    public var nextUpdate: Int64
    public var fetchInterval: Int
    public var dateAdded: Int64
    public var viewerFlags: Int64
    public var chapterFlags: Int64
    public var coverLastModified: Int64
    public var url: String
    public var title: String
    public var artist: String?
    public var author: String?
    public var mangaDescription: String?   // `description` avoids CustomStringConvertible clash
    public var genre: [String]?
    public var status: Int64
    public var thumbnailURL: String?
    public var updateStrategy: UpdateStrategy
    public var initialized: Bool
    public var lastModifiedAt: Int64
    public var favoriteModifiedAt: Int64?
    public var version: Int64
    public var notes: String
    public var memo: JSONValue

    public init(
        id: Int64 = -1,
        source: Int64 = -1,
        favorite: Bool = false,
        lastUpdate: Int64 = 0,
        nextUpdate: Int64 = 0,
        fetchInterval: Int = 0,
        dateAdded: Int64 = 0,
        viewerFlags: Int64 = 0,
        chapterFlags: Int64 = 0,
        coverLastModified: Int64 = 0,
        url: String = "",
        title: String = "",
        artist: String? = nil,
        author: String? = nil,
        mangaDescription: String? = nil,
        genre: [String]? = nil,
        status: Int64 = 0,
        thumbnailURL: String? = nil,
        updateStrategy: UpdateStrategy = .alwaysUpdate,
        initialized: Bool = false,
        lastModifiedAt: Int64 = 0,
        favoriteModifiedAt: Int64? = nil,
        version: Int64 = 0,
        notes: String = "",
        memo: JSONValue = .empty
    ) {
        self.id = id; self.source = source; self.favorite = favorite
        self.lastUpdate = lastUpdate; self.nextUpdate = nextUpdate
        self.fetchInterval = fetchInterval; self.dateAdded = dateAdded
        self.viewerFlags = viewerFlags; self.chapterFlags = chapterFlags
        self.coverLastModified = coverLastModified; self.url = url; self.title = title
        self.artist = artist; self.author = author; self.mangaDescription = mangaDescription
        self.genre = genre; self.status = status; self.thumbnailURL = thumbnailURL
        self.updateStrategy = updateStrategy; self.initialized = initialized
        self.lastModifiedAt = lastModifiedAt; self.favoriteModifiedAt = favoriteModifiedAt
        self.version = version; self.notes = notes; self.memo = memo
    }

    // MARK: chapterFlags bit constants (Manga.kt:87–113) — verbatim hex

    public static let chapterSortDesc: Int64 = 0x0000_0000
    public static let chapterSortAsc: Int64 = 0x0000_0001
    public static let chapterSortDirMask: Int64 = 0x0000_0001
    public static let chapterShowUnread: Int64 = 0x0000_0002
    public static let chapterShowRead: Int64 = 0x0000_0004
    public static let chapterUnreadMask: Int64 = 0x0000_0006
    public static let chapterShowDownloaded: Int64 = 0x0000_0008
    public static let chapterShowNotDownloaded: Int64 = 0x0000_0010
    public static let chapterDownloadedMask: Int64 = 0x0000_0018
    public static let chapterShowBookmarked: Int64 = 0x0000_0020
    public static let chapterShowNotBookmarked: Int64 = 0x0000_0040
    public static let chapterBookmarkedMask: Int64 = 0x0000_0060
    public static let chapterSortingSource: Int64 = 0x0000_0000
    public static let chapterSortingNumber: Int64 = 0x0000_0100
    public static let chapterSortingUploadDate: Int64 = 0x0000_0200
    public static let chapterSortingAlphabet: Int64 = 0x0000_0300
    public static let chapterSortingMask: Int64 = 0x0000_0300
    public static let chapterDisplayName: Int64 = 0x0000_0000
    public static let chapterDisplayNumber: Int64 = 0x0010_0000
    public static let chapterDisplayMask: Int64 = 0x0010_0000

    /// SManga.COMPLETED — used by `expectedNextUpdate`.
    public static let statusCompleted: Int64 = 2

    // MARK: chapterFlags accessors (values kept IN PLACE — compared to constants)

    public var sorting: Int64 { chapterFlags & Manga.chapterSortingMask }
    public var chapterDisplayModeRaw: Int64 { chapterFlags & Manga.chapterDisplayMask }
    public var unreadFilterRaw: Int64 { chapterFlags & Manga.chapterUnreadMask }
    public var downloadedFilterRaw: Int64 { chapterFlags & Manga.chapterDownloadedMask }
    public var bookmarkedFilterRaw: Int64 { chapterFlags & Manga.chapterBookmarkedMask }

    /// Descending when the direction bit is CLEARED (default state).
    public func sortDescending() -> Bool {
        (chapterFlags & Manga.chapterSortDirMask) == Manga.chapterSortDesc
    }

    public var unreadFilter: TriState {
        let raw = unreadFilterRaw
        if raw == Manga.chapterShowUnread { return .enabledIs }
        if raw == Manga.chapterShowRead { return .enabledNot }
        return .disabled   // incl. the invalid 0x6 combo
    }

    public var bookmarkedFilter: TriState {
        let raw = bookmarkedFilterRaw
        if raw == Manga.chapterShowBookmarked { return .enabledIs }
        if raw == Manga.chapterShowNotBookmarked { return .enabledNot }
        return .disabled
    }

    /// `nextUpdate` unless the series is COMPLETED (status == 2), then nil.
    public var expectedNextUpdate: Int64? {
        status == Manga.statusCompleted ? nil : nextUpdate
    }

    /// The universal bitfield read-modify-write. Reproduces Kotlin
    /// `this and mask.inv() or (flag and mask)` — explicit parens + the
    /// `(flag & mask)` guard that stops stray bits leaking into other fields.
    public static func setFlag(_ current: Int64, flag: Int64, mask: Int64) -> Int64 {
        (current & ~mask) | (flag & mask)
    }
}

/// Partial-update DTO (all nullable except `id`), mirroring Mihon's `MangaUpdate`
/// — every field is "leave unchanged if nil". Deliberately OMITS `lastModifiedAt`
/// and `favoriteModifiedAt` (DB/trigger-managed, not updatable via this path).
public struct MangaUpdate: Sendable, Hashable {
    public var id: Int64
    public var source: Int64?
    public var favorite: Bool?
    public var lastUpdate: Int64?
    public var nextUpdate: Int64?
    public var fetchInterval: Int?
    public var dateAdded: Int64?
    public var viewerFlags: Int64?
    public var chapterFlags: Int64?
    public var coverLastModified: Int64?
    public var url: String?
    public var title: String?
    public var artist: String?
    public var author: String?
    public var mangaDescription: String?
    public var genre: [String]?
    public var status: Int64?
    public var thumbnailURL: String?
    public var updateStrategy: UpdateStrategy?
    public var initialized: Bool?
    public var version: Int64?
    public var notes: String?
    public var memo: JSONValue?

    public init(id: Int64) { self.id = id }
}
