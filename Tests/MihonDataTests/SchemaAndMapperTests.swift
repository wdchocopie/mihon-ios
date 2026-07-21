import XCTest
@testable import MihonData
import MihonCore

final class SchemaTests: XCTestCase {

    func testAllTablesPresent() {
        for table in MihonSchema.tableNames {
            XCTAssertTrue(
                MihonSchema.baselineDDL.contains("CREATE TABLE \(table)"),
                "missing table \(table)"
            )
        }
    }

    func testAllSevenTriggersPresent() {
        XCTAssertEqual(MihonSchema.triggerNames.count, 7)
        for trigger in MihonSchema.triggerNames {
            XCTAssertTrue(
                MihonSchema.baselineDDL.contains(trigger),
                "missing trigger \(trigger)"
            )
        }
    }

    func testAllThreeViewsPresent() {
        for view in MihonSchema.viewNames {
            XCTAssertTrue(
                MihonSchema.baselineDDL.contains("CREATE VIEW \(view)"),
                "missing view \(view)"
            )
        }
    }

    func testVersionCounterTriggerLogicPresent() {
        // The sync version counters are the whole point of keeping triggers in SQL.
        XCTAssertTrue(MihonSchema.baselineDDL.contains("version = version + 1"))
        // Guarded on is_syncing = 0 (don't bump during a sync restore).
        XCTAssertTrue(MihonSchema.baselineDDL.contains("is_syncing = 0"))
    }

    func testSystemCategorySeeded() {
        XCTAssertTrue(MihonSchema.baselineDDL.contains(#"INSERT OR IGNORE INTO categories(_id, name, sort, flags) VALUES (0, "", -1, 0)"#))
        XCTAssertTrue(MihonSchema.baselineDDL.contains("System category can't be deleted"))
    }

    func testForeignKeyCascades() {
        // chapters/history/tracks cascade-delete with their manga/chapter.
        XCTAssertTrue(MihonSchema.baselineDDL.contains("ON DELETE CASCADE"))
    }
}

final class MapperTests: XCTestCase {

    func testMapMangaCoalescesNilDatesAndMapsInterval() {
        let manga = MangaMapper.mapManga(
            id: 5, source: 99, url: "/m", artist: nil, author: "A", description: nil,
            genre: ["X"], title: "T", status: 2, thumbnailUrl: nil, favorite: true,
            lastUpdate: nil, nextUpdate: nil, initialized: true, viewerFlags: 3,
            chapterFlags: 0x301, coverLastModified: 10, dateAdded: 20,
            updateStrategy: .onlyFetchOnce, calculateInterval: 14, lastModifiedAt: 30,
            favoriteModifiedAt: nil, version: 7, isSyncing: 0, notes: "n", memo: .empty
        )
        XCTAssertEqual(manga.id, 5)
        XCTAssertEqual(manga.lastUpdate, 0)      // nil → 0
        XCTAssertEqual(manga.nextUpdate, 0)      // nil → 0
        XCTAssertEqual(manga.fetchInterval, 14)  // calculateInterval → Int
        XCTAssertEqual(manga.updateStrategy, .onlyFetchOnce)
        XCTAssertEqual(manga.chapterFlags, 0x301)
        XCTAssertEqual(manga.genre, ["X"])
        XCTAssertEqual(manga.mangaDescription, nil)
    }

    func testMapChapter() {
        let c = ChapterMapper.mapChapter(
            id: 1, mangaId: 2, url: "/c", name: "Ch 1", scanlator: "grp",
            read: true, bookmark: false, lastPageRead: 12, chapterNumber: 1.5,
            sourceOrder: 0, dateFetch: 100, dateUpload: 200,
            lastModifiedAt: 5, version: 3, isSyncing: 0, memo: .empty
        )
        XCTAssertEqual(c.id, 1)
        XCTAssertEqual(c.mangaId, 2)
        XCTAssertEqual(c.chapterNumber, 1.5)
        XCTAssertTrue(c.read)
        XCTAssertEqual(c.scanlator, "grp")
        XCTAssertEqual(c.version, 3)
    }

    func testMapCategory() {
        let cat = CategoryMapper.mapCategory(id: 3, name: "Reading", order: 1, flags: 4)
        XCTAssertEqual(cat.id, 3)
        XCTAssertEqual(cat.name, "Reading")
        XCTAssertEqual(cat.order, 1)
        XCTAssertEqual(cat.flags, 4)
    }

    func testMapHistory() {
        let h = HistoryMapper.mapHistory(id: 1, chapterId: 2, lastRead: 1_700_000_000_000, timeRead: 5000)
        XCTAssertEqual(h.chapterId, 2)
        XCTAssertEqual(h.readAt, 1_700_000_000_000)
        XCTAssertEqual(h.readDuration, 5000)
    }

    func testMapTrack() {
        let t = TrackMapper.mapTrack(
            id: 1, mangaId: 2, syncId: 3, remoteId: 42, libraryId: nil, title: "MAL",
            lastChapterRead: 12.0, totalChapters: 100, status: 1, score: 8.5,
            remoteUrl: "https://x", startDate: 0, finishDate: 0, private: true
        )
        XCTAssertEqual(t.trackerId, 3)
        XCTAssertEqual(t.remoteId, 42)
        XCTAssertEqual(t.title, "MAL")
        XCTAssertEqual(t.score, 8.5)
        XCTAssertTrue(t.private)
    }
}
