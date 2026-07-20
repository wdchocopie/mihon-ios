import Foundation

/// A manga as returned by a source. Mirrors Mihon's `SManga`
/// (`source-api/.../model/SManga.kt`) but as an idiomatic Swift value type
/// rather than a mutable interface.
///
/// Behavioral note for parity: `genre` is a `[String]` here, but the DB stores
/// it as a single TEXT column joined by `", "` — that separator is
/// backup-boundary-significant and must round-trip exactly (see plan R / ADR-2).
public struct SManga: Sendable, Hashable, Codable {
    public var url: String
    public var title: String
    public var thumbnailURL: String?
    public var artist: String?
    public var author: String?
    public var status: MangaStatus
    public var description: String?
    public var genre: [String]?
    public var updateStrategy: UpdateStrategy
    public var initialized: Bool

    // TODO(port): `memo: JsonObject` (source-specific metadata, since
    // tachiyomix 1.6). Model once the JSON representation is settled.

    public init(
        url: String,
        title: String,
        thumbnailURL: String? = nil,
        artist: String? = nil,
        author: String? = nil,
        status: MangaStatus = .unknown,
        description: String? = nil,
        genre: [String]? = nil,
        updateStrategy: UpdateStrategy = .alwaysUpdate,
        initialized: Bool = false
    ) {
        self.url = url
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.artist = artist
        self.author = author
        self.status = status
        self.description = description
        self.genre = genre
        self.updateStrategy = updateStrategy
        self.initialized = initialized
    }
}

/// Publication status. Raw values match Mihon's constants exactly — they are
/// persisted and cross the backup boundary, so they must not be renumbered.
public enum MangaStatus: Int, Sendable, Codable, CaseIterable {
    case unknown = 0
    case ongoing = 1
    case completed = 2
    case licensed = 3
    case publishingFinished = 4
    case cancelled = 5
    case onHiatus = 6
}
