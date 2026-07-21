import Foundation

/// A chapter **domain** entity, ported from `domain/.../chapter/model/Chapter.kt`.
/// `chapterNumber` is a `Double` (not Float). `create()` defaults are non-trivial:
/// version = 1 (NOT 0), dateUpload = -1, chapterNumber = -1.0.
public struct Chapter: Sendable, Hashable, Identifiable, Codable {
    public var id: Int64
    public var mangaId: Int64
    public var read: Bool
    public var bookmark: Bool
    public var lastPageRead: Int64
    public var dateFetch: Int64
    public var sourceOrder: Int64
    public var url: String
    public var name: String
    public var dateUpload: Int64
    public var chapterNumber: Double
    public var scanlator: String?
    public var lastModifiedAt: Int64
    public var version: Int64
    public var memo: JSONValue

    public init(
        id: Int64 = -1,
        mangaId: Int64 = -1,
        read: Bool = false,
        bookmark: Bool = false,
        lastPageRead: Int64 = 0,
        dateFetch: Int64 = 0,
        sourceOrder: Int64 = 0,
        url: String = "",
        name: String = "",
        dateUpload: Int64 = -1,
        chapterNumber: Double = -1.0,
        scanlator: String? = nil,
        lastModifiedAt: Int64 = 0,
        version: Int64 = 1,
        memo: JSONValue = .empty
    ) {
        self.id = id; self.mangaId = mangaId; self.read = read; self.bookmark = bookmark
        self.lastPageRead = lastPageRead; self.dateFetch = dateFetch
        self.sourceOrder = sourceOrder; self.url = url; self.name = name
        self.dateUpload = dateUpload; self.chapterNumber = chapterNumber
        self.scanlator = scanlator; self.lastModifiedAt = lastModifiedAt
        self.version = version; self.memo = memo
    }

    public var isRecognizedNumber: Bool { chapterNumber >= 0 }

    /// Merge source-updated fields onto an existing chapter, preserving
    /// id/read/bookmark/etc. A blank (whitespace-only) scanlator becomes nil.
    public func copyFrom(_ other: Chapter) -> Chapter {
        var c = self
        c.name = other.name
        c.url = other.url
        c.dateUpload = other.dateUpload
        c.chapterNumber = other.chapterNumber
        // Blank check uses Kotlin's whitespace set (isKotlinWhitespace); the value
        // itself is kept untrimmed, matching the Chapter→Chapter copy.
        if let s = other.scanlator, !trimKotlinWhitespace(s).isEmpty {
            c.scanlator = s
        } else {
            c.scanlator = nil
        }
        return c
    }
}

/// Partial-update DTO for a chapter (all nullable except `id`).
public struct ChapterUpdate: Sendable, Hashable {
    public var id: Int64
    public var mangaId: Int64?
    public var read: Bool?
    public var bookmark: Bool?
    public var lastPageRead: Int64?
    public var dateFetch: Int64?
    public var sourceOrder: Int64?
    public var url: String?
    public var name: String?
    public var dateUpload: Int64?
    public var chapterNumber: Double?
    public var scanlator: String?
    public var version: Int64?
    public var memo: JSONValue?

    public init(id: Int64) { self.id = id }
}
