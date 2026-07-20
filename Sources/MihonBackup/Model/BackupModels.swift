import Foundation

// Swift models for the `.tachibk` protobuf schema, ported field-for-field from
// Mihon's `data/backup/models/*.kt`. Field numbers and DEFAULTS are load-bearing:
// an absent field decodes to its Kotlin default, and getting a default wrong
// silently corrupts a restored library (see `BackupManga.favorite = true`).
// See docs/specs/2026-07-20-tachibk-decoder-design.md for the derived schema.
//
// `encode()` writes all present fields — enough for the round-trip test. A
// Mihon-byte-exact export additionally omits default-valued fields (deferred).

// MARK: - Root

public struct Backup: Sendable, Equatable {
    public var backupManga: [BackupManga]
    public var backupCategories: [BackupCategory]
    public var backupSources: [BackupSource]
    // Fields 104/105/106 (preferences, source preferences, extension stores)
    // are skipped on decode for now — see spec. Field 100 is a legacy gap.

    public init(
        backupManga: [BackupManga] = [],
        backupCategories: [BackupCategory] = [],
        backupSources: [BackupSource] = []
    ) {
        self.backupManga = backupManga
        self.backupCategories = backupCategories
        self.backupSources = backupSources
    }

    public static func decode(_ data: [UInt8]) throws -> Backup {
        var r = ProtobufWireReader(data)
        var b = Backup()
        while let (field, wire) = try r.readTag() {
            switch field {
            case 1: b.backupManga.append(try BackupManga.decode(r.readBytes()))
            case 2: b.backupCategories.append(try BackupCategory.decode(r.readBytes()))
            case 101: b.backupSources.append(try BackupSource.decode(r.readBytes()))
            default: try r.skip(wire) // 100 legacy, 104/105/106 deferred, unknowns
            }
        }
        return b
    }

    public func encode() -> [UInt8] {
        var w = ProtobufWireWriter()
        for m in backupManga { w.message(1, m.encode()) }
        for c in backupCategories { w.message(2, c.encode()) }
        for s in backupSources { w.message(101, s.encode()) }
        return w.bytes
    }
}

// MARK: - Manga

public struct BackupManga: Sendable, Equatable {
    public var source: Int64
    public var url: String
    public var title: String
    public var artist: String?
    public var author: String?
    public var description: String?
    public var genre: [String]
    public var status: Int
    public var thumbnailURL: String?
    public var dateAdded: Int64
    public var viewer: Int
    public var chapters: [BackupChapter]
    public var categories: [Int64]
    public var tracking: [BackupTracking]
    public var favorite: Bool          // field 100 — DEFAULT TRUE (data-loss trap)
    public var chapterFlags: Int
    public var viewerFlags: Int?       // field 103 — restore uses viewerFlags ?? viewer
    public var history: [BackupHistory]
    public var updateStrategy: Int     // enum ordinal; 0 = ALWAYS_UPDATE
    public var lastModifiedAt: Int64
    public var favoriteModifiedAt: Int64?
    public var excludedScanlators: [String]
    public var version: Int64
    public var notes: String
    public var initialized: Bool
    public var memo: [UInt8]           // opaque JSON bytes; TODO confirm default

    public init(
        source: Int64,
        url: String,
        title: String = "",
        artist: String? = nil,
        author: String? = nil,
        description: String? = nil,
        genre: [String] = [],
        status: Int = 0,
        thumbnailURL: String? = nil,
        dateAdded: Int64 = 0,
        viewer: Int = 0,
        chapters: [BackupChapter] = [],
        categories: [Int64] = [],
        tracking: [BackupTracking] = [],
        favorite: Bool = true,
        chapterFlags: Int = 0,
        viewerFlags: Int? = nil,
        history: [BackupHistory] = [],
        updateStrategy: Int = 0,
        lastModifiedAt: Int64 = 0,
        favoriteModifiedAt: Int64? = nil,
        excludedScanlators: [String] = [],
        version: Int64 = 0,
        notes: String = "",
        initialized: Bool = false,
        memo: [UInt8] = []
    ) {
        self.source = source; self.url = url; self.title = title
        self.artist = artist; self.author = author; self.description = description
        self.genre = genre; self.status = status; self.thumbnailURL = thumbnailURL
        self.dateAdded = dateAdded; self.viewer = viewer; self.chapters = chapters
        self.categories = categories; self.tracking = tracking; self.favorite = favorite
        self.chapterFlags = chapterFlags; self.viewerFlags = viewerFlags
        self.history = history; self.updateStrategy = updateStrategy
        self.lastModifiedAt = lastModifiedAt; self.favoriteModifiedAt = favoriteModifiedAt
        self.excludedScanlators = excludedScanlators; self.version = version
        self.notes = notes; self.initialized = initialized; self.memo = memo
    }

    /// Restore parity with MangaRestorer: viewer flags fall back to `viewer`.
    public var effectiveViewerFlags: Int { viewerFlags ?? viewer }

    public static func decode(_ data: [UInt8]) throws -> BackupManga {
        var r = ProtobufWireReader(data)
        var m = BackupManga(source: 0, url: "")
        while let (field, wire) = try r.readTag() {
            switch field {
            case 1: m.source = try r.readInt64()
            case 2: m.url = try r.readString()
            case 3: m.title = try r.readString()
            case 4: m.artist = try r.readString()
            case 5: m.author = try r.readString()
            case 6: m.description = try r.readString()
            case 7: m.genre.append(try r.readString())
            case 8: m.status = try r.readInt()
            case 9: m.thumbnailURL = try r.readString()
            case 13: m.dateAdded = try r.readInt64()
            case 14: m.viewer = try r.readInt()
            case 16: m.chapters.append(try BackupChapter.decode(r.readBytes()))
            case 17: m.categories.append(try r.readInt64())
            case 18: m.tracking.append(try BackupTracking.decode(r.readBytes()))
            case 100: m.favorite = try r.readBool()
            case 101: m.chapterFlags = try r.readInt()
            case 103: m.viewerFlags = try r.readInt()
            case 104: m.history.append(try BackupHistory.decode(r.readBytes()))
            case 105: m.updateStrategy = try r.readInt()
            case 106: m.lastModifiedAt = try r.readInt64()
            case 107: m.favoriteModifiedAt = try r.readInt64()
            case 108: m.excludedScanlators.append(try r.readString())
            case 109: m.version = try r.readInt64()
            case 110: m.notes = try r.readString()
            case 111: m.initialized = try r.readBool()
            case 112: m.memo = try r.readBytes()
            default: try r.skip(wire)
            }
        }
        return m
    }

    public func encode() -> [UInt8] {
        var w = ProtobufWireWriter()
        w.int64(1, source)
        w.string(2, url)
        w.string(3, title)
        if let artist { w.string(4, artist) }
        if let author { w.string(5, author) }
        if let description { w.string(6, description) }
        for g in genre { w.string(7, g) }
        w.int(8, status)
        if let thumbnailURL { w.string(9, thumbnailURL) }
        w.int64(13, dateAdded)
        w.int(14, viewer)
        for c in chapters { w.message(16, c.encode()) }
        for c in categories { w.int64(17, c) }
        for t in tracking { w.message(18, t.encode()) }
        w.bool(100, favorite)
        w.int(101, chapterFlags)
        if let viewerFlags { w.int(103, viewerFlags) }
        for h in history { w.message(104, h.encode()) }
        w.int(105, updateStrategy)
        w.int64(106, lastModifiedAt)
        if let favoriteModifiedAt { w.int64(107, favoriteModifiedAt) }
        for s in excludedScanlators { w.string(108, s) }
        w.int64(109, version)
        w.string(110, notes)
        w.bool(111, initialized)
        w.bytesField(112, memo)
        return w.bytes
    }
}

// MARK: - Chapter

public struct BackupChapter: Sendable, Equatable {
    public var url: String
    public var name: String
    public var scanlator: String?
    public var read: Bool
    public var bookmark: Bool
    public var lastPageRead: Int64
    public var dateFetch: Int64
    public var dateUpload: Int64
    public var chapterNumber: Float
    public var sourceOrder: Int64
    public var lastModifiedAt: Int64
    public var version: Int64
    public var memo: [UInt8]

    public init(
        url: String, name: String, scanlator: String? = nil,
        read: Bool = false, bookmark: Bool = false, lastPageRead: Int64 = 0,
        dateFetch: Int64 = 0, dateUpload: Int64 = 0, chapterNumber: Float = 0,
        sourceOrder: Int64 = 0, lastModifiedAt: Int64 = 0, version: Int64 = 0,
        memo: [UInt8] = []
    ) {
        self.url = url; self.name = name; self.scanlator = scanlator
        self.read = read; self.bookmark = bookmark; self.lastPageRead = lastPageRead
        self.dateFetch = dateFetch; self.dateUpload = dateUpload
        self.chapterNumber = chapterNumber; self.sourceOrder = sourceOrder
        self.lastModifiedAt = lastModifiedAt; self.version = version; self.memo = memo
    }

    public static func decode(_ data: [UInt8]) throws -> BackupChapter {
        var r = ProtobufWireReader(data)
        var c = BackupChapter(url: "", name: "")
        while let (field, wire) = try r.readTag() {
            switch field {
            case 1: c.url = try r.readString()
            case 2: c.name = try r.readString()
            case 3: c.scanlator = try r.readString()
            case 4: c.read = try r.readBool()
            case 5: c.bookmark = try r.readBool()
            case 6: c.lastPageRead = try r.readInt64()
            case 7: c.dateFetch = try r.readInt64()
            case 8: c.dateUpload = try r.readInt64()
            case 9: c.chapterNumber = try r.readFloat()
            case 10: c.sourceOrder = try r.readInt64()
            case 11: c.lastModifiedAt = try r.readInt64()
            case 12: c.version = try r.readInt64()
            case 13: c.memo = try r.readBytes()
            default: try r.skip(wire)
            }
        }
        return c
    }

    public func encode() -> [UInt8] {
        var w = ProtobufWireWriter()
        w.string(1, url); w.string(2, name)
        if let scanlator { w.string(3, scanlator) }
        w.bool(4, read); w.bool(5, bookmark)
        w.int64(6, lastPageRead); w.int64(7, dateFetch); w.int64(8, dateUpload)
        w.float(9, chapterNumber); w.int64(10, sourceOrder)
        w.int64(11, lastModifiedAt); w.int64(12, version); w.bytesField(13, memo)
        return w.bytes
    }
}

// MARK: - Category / Source / History / Tracking

public struct BackupCategory: Sendable, Equatable {
    public var name: String
    public var order: Int64
    public var id: Int64
    public var flags: Int64

    public init(name: String, order: Int64 = 0, id: Int64 = 0, flags: Int64 = 0) {
        self.name = name; self.order = order; self.id = id; self.flags = flags
    }

    public static func decode(_ data: [UInt8]) throws -> BackupCategory {
        var r = ProtobufWireReader(data)
        var c = BackupCategory(name: "")
        while let (field, wire) = try r.readTag() {
            switch field {
            case 1: c.name = try r.readString()
            case 2: c.order = try r.readInt64()
            case 3: c.id = try r.readInt64()
            case 100: c.flags = try r.readInt64()
            default: try r.skip(wire)
            }
        }
        return c
    }

    public func encode() -> [UInt8] {
        var w = ProtobufWireWriter()
        w.string(1, name); w.int64(2, order); w.int64(3, id); w.int64(100, flags)
        return w.bytes
    }
}

public struct BackupSource: Sendable, Equatable {
    public var name: String
    public var sourceId: Int64

    public init(name: String = "", sourceId: Int64) {
        self.name = name; self.sourceId = sourceId
    }

    public static func decode(_ data: [UInt8]) throws -> BackupSource {
        var r = ProtobufWireReader(data)
        var s = BackupSource(sourceId: 0)
        while let (field, wire) = try r.readTag() {
            switch field {
            case 1: s.name = try r.readString()
            case 2: s.sourceId = try r.readInt64()
            default: try r.skip(wire)
            }
        }
        return s
    }

    public func encode() -> [UInt8] {
        var w = ProtobufWireWriter()
        w.string(1, name); w.int64(2, sourceId)
        return w.bytes
    }
}

public struct BackupHistory: Sendable, Equatable {
    public var url: String
    public var lastRead: Int64
    public var readDuration: Int64

    public init(url: String, lastRead: Int64, readDuration: Int64 = 0) {
        self.url = url; self.lastRead = lastRead; self.readDuration = readDuration
    }

    public static func decode(_ data: [UInt8]) throws -> BackupHistory {
        var r = ProtobufWireReader(data)
        var h = BackupHistory(url: "", lastRead: 0)
        while let (field, wire) = try r.readTag() {
            switch field {
            case 1: h.url = try r.readString()
            case 2: h.lastRead = try r.readInt64()
            case 3: h.readDuration = try r.readInt64()
            default: try r.skip(wire)
            }
        }
        return h
    }

    public func encode() -> [UInt8] {
        var w = ProtobufWireWriter()
        w.string(1, url); w.int64(2, lastRead); w.int64(3, readDuration)
        return w.bytes
    }
}

public struct BackupTracking: Sendable, Equatable {
    public var syncId: Int
    public var libraryId: Int64
    public var mediaIdInt: Int      // deprecated field 3; restore: remoteId = mediaIdInt != 0 ? mediaIdInt : mediaId
    public var trackingUrl: String
    public var title: String
    public var lastChapterRead: Float
    public var totalChapters: Int
    public var score: Float
    public var status: Int
    public var startedReadingDate: Int64
    public var finishedReadingDate: Int64
    public var `private`: Bool
    public var mediaId: Int64        // field 100

    public init(
        syncId: Int, libraryId: Int64, mediaIdInt: Int = 0, trackingUrl: String = "",
        title: String = "", lastChapterRead: Float = 0, totalChapters: Int = 0,
        score: Float = 0, status: Int = 0, startedReadingDate: Int64 = 0,
        finishedReadingDate: Int64 = 0, private: Bool = false, mediaId: Int64 = 0
    ) {
        self.syncId = syncId; self.libraryId = libraryId; self.mediaIdInt = mediaIdInt
        self.trackingUrl = trackingUrl; self.title = title
        self.lastChapterRead = lastChapterRead; self.totalChapters = totalChapters
        self.score = score; self.status = status
        self.startedReadingDate = startedReadingDate
        self.finishedReadingDate = finishedReadingDate
        self.private = `private`; self.mediaId = mediaId
    }

    /// Restore parity: the burned field-3/field-100 media-id split.
    public var remoteId: Int64 { mediaIdInt != 0 ? Int64(mediaIdInt) : mediaId }

    public static func decode(_ data: [UInt8]) throws -> BackupTracking {
        var r = ProtobufWireReader(data)
        var t = BackupTracking(syncId: 0, libraryId: 0)
        while let (field, wire) = try r.readTag() {
            switch field {
            case 1: t.syncId = try r.readInt()
            case 2: t.libraryId = try r.readInt64()
            case 3: t.mediaIdInt = try r.readInt()
            case 4: t.trackingUrl = try r.readString()
            case 5: t.title = try r.readString()
            case 6: t.lastChapterRead = try r.readFloat()
            case 7: t.totalChapters = try r.readInt()
            case 8: t.score = try r.readFloat()
            case 9: t.status = try r.readInt()
            case 10: t.startedReadingDate = try r.readInt64()
            case 11: t.finishedReadingDate = try r.readInt64()
            case 12: t.private = try r.readBool()
            case 100: t.mediaId = try r.readInt64()
            default: try r.skip(wire)
            }
        }
        return t
    }

    public func encode() -> [UInt8] {
        var w = ProtobufWireWriter()
        w.int(1, syncId); w.int64(2, libraryId); w.int(3, mediaIdInt)
        w.string(4, trackingUrl); w.string(5, title)
        w.float(6, lastChapterRead); w.int(7, totalChapters); w.float(8, score)
        w.int(9, status); w.int64(10, startedReadingDate)
        w.int64(11, finishedReadingDate); w.bool(12, `private`); w.int64(100, mediaId)
        return w.bytes
    }
}
