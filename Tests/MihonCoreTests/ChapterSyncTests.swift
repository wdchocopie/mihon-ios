import XCTest
@testable import MihonCore

final class ChapterSanitizerTests: XCTestCase {
    func testStripsTitlePrefixAndSeparators() {
        XCTAssertEqual(ChapterSanitizer.sanitize("One Piece - Chapter 5", title: "One Piece"), "Chapter 5")
        XCTAssertEqual(ChapterSanitizer.sanitize("  : Bleach :  ", title: "X"), "Bleach")
        XCTAssertEqual(ChapterSanitizer.sanitize("Naruto", title: "Naruto"), "")
    }

    // Kotlin whitespace ≠ Swift Unicode White_Space (verification Finding 1).
    func testKotlinWhitespaceSet() {
        // U+001C (FS) IS Kotlin-whitespace → step-1 trims it, prefix removed.
        XCTAssertEqual(
            ChapterSanitizer.sanitize("\u{1C}One Piece Chapter 5", title: "One Piece"),
            "Chapter 5"
        )
        // U+0085 (NEL) is NOT Kotlin-whitespace → not trimmed in step 1, so the
        // prefix stays glued and is not removed (only the trailing/leading trimChars run).
        XCTAssertEqual(
            ChapterSanitizer.sanitize("\u{85}One Piece 5", title: "One Piece"),
            "One Piece 5"
        )
        // Scanlator: lone NEL is NOT blank in Kotlin → stays; lone FS IS blank → nil.
        XCTAssertEqual(normalizeScanlator("\u{85}"), "\u{85}")
        XCTAssertNil(normalizeScanlator("\u{1C}"))
        XCTAssertNil(normalizeScanlator("   "))
        XCTAssertEqual(normalizeScanlator("\u{1C}Group"), "Group")
    }
}

final class ChapterSyncTests: XCTestCase {
    private let manga = Manga(id: 1, title: "Test")
    private let now: Int64 = 1_700_000_000_000

    func testAddsBrandNewChapters() {
        let result = ChapterSync.compute(
            rawSourceChapters: [SChapter(url: "/c/1", name: "Ch 1"), SChapter(url: "/c/2", name: "Ch 2")],
            manga: manga, dbChapters: [], nowMillis: now
        )
        XCTAssertEqual(result.toAdd.count, 2)
        XCTAssertTrue(result.toUpdate.isEmpty)
        XCTAssertTrue(result.toDeleteIds.isEmpty)
        // dateFetch is descending: first (most recent) gets the highest value.
        XCTAssertGreaterThan(result.toAdd[0].dateFetch, result.toAdd[1].dateFetch)
        // Missing dateUpload → nowMillis for the first new chapter.
        XCTAssertEqual(result.toAdd[0].dateUpload, now)
    }

    func testDeletesChaptersNoLongerOffered() {
        let db = [Chapter(id: 10, mangaId: 1, url: "/c/1", name: "Ch 1")]
        let result = ChapterSync.compute(
            rawSourceChapters: [SChapter(url: "/c/2", name: "Ch 2")],
            manga: manga, dbChapters: db, nowMillis: now
        )
        XCTAssertEqual(result.toDeleteIds, [10])
        XCTAssertEqual(result.toAdd.count, 1)
    }

    func testNoChangesWhenSourceMatchesDb() {
        // db chapter must match every field ShouldUpdateDbChapter compares,
        // including dateUpload (an unguarded != in Mihon).
        let db = [Chapter(id: 10, mangaId: 1, url: "/c/1", name: "Ch 1",
                          dateUpload: 1000, chapterNumber: 1)]
        let result = ChapterSync.compute(
            rawSourceChapters: [SChapter(url: "/c/1", name: "Ch 1", chapterNumber: 1, dateUpload: 1000)],
            manga: manga, dbChapters: db, nowMillis: now
        )
        XCTAssertFalse(result.hasChanges)
    }

    // The core reason this logic exists: a re-uploaded chapter the user already
    // read (same chapter number, new URL) must come back READ.
    func testReadStateInheritedFromDeletedChapterOfSameNumber() {
        let db = [Chapter(id: 10, mangaId: 1, read: true, bookmark: true, dateFetch: 999,
                          url: "/old/5", name: "Ch 5", chapterNumber: 5)]
        let result = ChapterSync.compute(
            rawSourceChapters: [SChapter(url: "/new/5", name: "Ch 5", chapterNumber: 5)],
            manga: manga, dbChapters: db, nowMillis: now
        )
        XCTAssertEqual(result.toDeleteIds, [10])          // old removed
        XCTAssertEqual(result.toAdd.count, 1)
        let readded = result.toAdd[0]
        XCTAssertTrue(readded.read, "re-added chapter must inherit read state")
        XCTAssertTrue(readded.bookmark, "re-added chapter must inherit bookmark state")
        XCTAssertEqual(readded.dateFetch, 999, "reuses the original fetch date")
        XCTAssertTrue(result.changedOrDuplicateReadUrls.contains("/new/5"))
    }

    func testMarkDuplicateAsReadWhenNumberAlreadyRead() {
        let db = [Chapter(id: 10, mangaId: 1, read: true, url: "/c/5", name: "Ch 5", chapterNumber: 5)]
        // Source still offers /c/5 AND a duplicate /c/5b with the same number.
        let result = ChapterSync.compute(
            rawSourceChapters: [
                SChapter(url: "/c/5", name: "Ch 5", chapterNumber: 5),
                SChapter(url: "/c/5b", name: "Ch 5", chapterNumber: 5),
            ],
            manga: manga, dbChapters: db, nowMillis: now, markDuplicateAsRead: true
        )
        let dup = result.toAdd.first { $0.url == "/c/5b" }
        XCTAssertEqual(dup?.read, true)
        XCTAssertTrue(result.changedOrDuplicateReadUrls.contains("/c/5b"))
    }

    func testUpdatesChangedChapterMetadata() {
        let db = [Chapter(id: 10, mangaId: 1, url: "/c/1", name: "Old name", chapterNumber: 1)]
        let result = ChapterSync.compute(
            rawSourceChapters: [SChapter(url: "/c/1", name: "New name", chapterNumber: 1)],
            manga: manga, dbChapters: db, nowMillis: now
        )
        XCTAssertEqual(result.toUpdate.count, 1)
        XCTAssertEqual(result.toUpdate[0].name, "New name")
        XCTAssertEqual(result.toUpdate[0].id, 10)  // same row
    }

    func testDeduplicatesSourceChaptersByUrl() {
        let result = ChapterSync.compute(
            rawSourceChapters: [SChapter(url: "/c/1", name: "A"), SChapter(url: "/c/1", name: "B")],
            manga: manga, dbChapters: [], nowMillis: now
        )
        XCTAssertEqual(result.toAdd.count, 1)
    }

    func testNewlyAddedExcludesScanlatorsAndDuplicates() {
        let added = [
            Chapter(id: 1, url: "/a", name: "A", scanlator: "GoodGrp"),
            Chapter(id: 2, url: "/b", name: "B", scanlator: "BadGrp"),
            Chapter(id: 3, url: "/c", name: "C"),
        ]
        let out = ChapterSync.newlyAdded(
            added: added, changedOrDuplicateReadUrls: ["/c"], excludedScanlators: ["BadGrp"]
        )
        XCTAssertEqual(out.map(\.url), ["/a"])  // /b excluded scanlator, /c duplicate-read
    }
}

final class GetNextChaptersTests: XCTestCase {
    private let manga = Manga(id: 1, title: "T")

    // sourceOrder 0 = newest (sources return most-recent first), so reading order
    // = DESCENDING sourceOrder. With order: id1=oldest, id3=newest, reading order
    // is [id1, id2, id3].
    private func ch(_ id: Int64, order: Int64, read: Bool = false) -> Chapter {
        Chapter(id: id, mangaId: 1, read: read, sourceOrder: order, chapterNumber: Double(order))
    }

    func testUnreadOnlyReturnsOldestUnreadFirst() {
        let chapters = [ch(1, order: 2, read: true), ch(2, order: 1), ch(3, order: 0)]
        let next = GetNextChapters.compute(manga: manga, chapters: chapters)
        XCTAssertEqual(next.map(\.id), [2, 3])  // oldest (id1) is read → next is id2, id3
    }

    func testFromChapterReturnsSubsequent() {
        let chapters = [ch(1, order: 2), ch(2, order: 1), ch(3, order: 0)]
        let next = GetNextChapters.compute(manga: manga, chapters: chapters,
                                           fromChapterId: 2, onlyUnread: true)
        XCTAssertEqual(next.map(\.id), [2, 3])  // from id2 onward in reading order
    }

    func testFromReadChapterNotOnlyUnreadDropsCurrent() {
        let chapters = [ch(1, order: 2, read: true), ch(2, order: 1), ch(3, order: 0)]
        let next = GetNextChapters.compute(manga: manga, chapters: chapters,
                                           fromChapterId: 1, onlyUnread: false)
        XCTAssertEqual(next.map(\.id), [2, 3])  // current (id1) is read → dropped
    }
}
