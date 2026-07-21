import Foundation
import MihonCore

// Row-columns → domain-entity mappers, ported from Mihon's `*Mapper.kt`. The
// column adapters (genre/updateStrategy/memo) run first (raw DB value → typed),
// then these assemble the entity. GRDB-agnostic and Windows-testable: the GRDB
// tier will feed real row values into these same functions.

public enum MangaMapper {
    /// Mirrors `MangaMapper.mapManga`. `isSyncing` is accepted for column-parity
    /// but unused (as in Kotlin). `lastUpdate`/`nextUpdate` coalesce nil → 0;
    /// `calculateInterval` becomes `fetchInterval: Int`.
    public static func mapManga(
        id: Int64, source: Int64, url: String, artist: String?, author: String?,
        description: String?, genre: [String]?, title: String, status: Int64,
        thumbnailUrl: String?, favorite: Bool, lastUpdate: Int64?, nextUpdate: Int64?,
        initialized: Bool, viewerFlags: Int64, chapterFlags: Int64, coverLastModified: Int64,
        dateAdded: Int64, updateStrategy: UpdateStrategy, calculateInterval: Int64,
        lastModifiedAt: Int64, favoriteModifiedAt: Int64?, version: Int64, isSyncing: Int64,
        notes: String, memo: JSONValue
    ) -> Manga {
        Manga(
            id: id, source: source, favorite: favorite,
            lastUpdate: lastUpdate ?? 0, nextUpdate: nextUpdate ?? 0,
            fetchInterval: Int(truncatingIfNeeded: calculateInterval),
            dateAdded: dateAdded, viewerFlags: viewerFlags, chapterFlags: chapterFlags,
            coverLastModified: coverLastModified, url: url, title: title,
            artist: artist, author: author, mangaDescription: description, genre: genre,
            status: status, thumbnailURL: thumbnailUrl, updateStrategy: updateStrategy,
            initialized: initialized, lastModifiedAt: lastModifiedAt,
            favoriteModifiedAt: favoriteModifiedAt, version: version, notes: notes, memo: memo
        )
    }
}

public enum ChapterMapper {
    /// Mirrors `ChapterMapper.mapChapter`. `isSyncing` accepted but unused.
    public static func mapChapter(
        id: Int64, mangaId: Int64, url: String, name: String, scanlator: String?,
        read: Bool, bookmark: Bool, lastPageRead: Int64, chapterNumber: Double,
        sourceOrder: Int64, dateFetch: Int64, dateUpload: Int64,
        lastModifiedAt: Int64, version: Int64, isSyncing: Int64, memo: JSONValue
    ) -> Chapter {
        Chapter(
            id: id, mangaId: mangaId, read: read, bookmark: bookmark,
            lastPageRead: lastPageRead, dateFetch: dateFetch, sourceOrder: sourceOrder,
            url: url, name: name, dateUpload: dateUpload, chapterNumber: chapterNumber,
            scanlator: scanlator, lastModifiedAt: lastModifiedAt, version: version, memo: memo
        )
    }
}

public enum CategoryMapper {
    /// `getCategories` returns `_id AS id, name, sort AS order, flags`.
    public static func mapCategory(id: Int64, name: String, order: Int64, flags: Int64) -> Category {
        Category(id: id, name: name, order: order, flags: flags)
    }
}

public enum HistoryMapper {
    /// `history` row: `_id, chapter_id, last_read (Date/epoch millis, nullable),
    /// time_read`. Maps to the `History` domain entity.
    public static func mapHistory(
        id: Int64, chapterId: Int64, lastRead: Int64?, timeRead: Int64
    ) -> History {
        History(id: id, chapterId: chapterId, readAt: lastRead, readDuration: timeRead)
    }
}

public enum TrackMapper {
    /// `manga_sync` row → `Track`. `sync_id` is the tracker id, `remote_id` the
    /// remote media id, `library_id` nullable.
    public static func mapTrack(
        id: Int64, mangaId: Int64, syncId: Int64, remoteId: Int64, libraryId: Int64?,
        title: String, lastChapterRead: Double, totalChapters: Int64, status: Int64,
        score: Double, remoteUrl: String, startDate: Int64, finishDate: Int64, `private`: Bool
    ) -> Track {
        Track(
            id: id, mangaId: mangaId, trackerId: syncId, remoteId: remoteId,
            libraryId: libraryId, title: title, lastChapterRead: lastChapterRead,
            totalChapters: totalChapters, status: status, score: score,
            remoteUrl: remoteUrl, startDate: startDate, finishDate: finishDate, private: `private`
        )
    }
}
