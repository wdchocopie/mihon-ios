import XCTest
@testable import MihonCore

/// Bit-exactness tests for the chapterFlags bitfield, the SetMangaChapterFlags
/// transitions, TriState decode, LibrarySort golden vectors, and the
/// ShouldUpdateDbChapter dirty-check. These values cross the `.tachibk`/DB
/// boundary, so a paraphrase silently corrupts user data.
final class MangaFlagsTests: XCTestCase {

    // MARK: - chapterFlags pack / unpack round-trips

    func testSetAllFlagsRoundTripsAcrossCombos() {
        let unreadCases: [(Int64, TriState)] = [
            (Manga.chapterShowUnread, .enabledIs),
            (Manga.chapterShowRead, .enabledNot),
            (0, .disabled),
        ]
        let sortModes: [Int64] = [
            Manga.chapterSortingSource,
            Manga.chapterSortingNumber,
            Manga.chapterSortingUploadDate,
            Manga.chapterSortingAlphabet,
        ]
        let directions: [(Int64, Bool)] = [
            (Manga.chapterSortAsc, false),   // ascending → sortDescending() == false
            (Manga.chapterSortDesc, true),   // descending → sortDescending() == true
        ]
        let displayModes: [Int64] = [Manga.chapterDisplayName, Manga.chapterDisplayNumber]

        for (unreadBits, expectedTriState) in unreadCases {
            for mode in sortModes {
                for (dirBits, expectedDescending) in directions {
                    for display in displayModes {
                        let flags = SetMangaChapterFlags.setAllFlags(
                            unread: unreadBits,
                            downloaded: Manga.chapterShowDownloaded,
                            bookmarked: Manga.chapterShowBookmarked,
                            sortingMode: mode,
                            sortingDirection: dirBits,
                            displayMode: display
                        )
                        let manga = Manga(chapterFlags: flags)

                        XCTAssertEqual(manga.unreadFilter, expectedTriState)
                        XCTAssertEqual(manga.sorting, mode)
                        XCTAssertEqual(manga.sortDescending(), expectedDescending)
                        XCTAssertEqual(manga.chapterDisplayModeRaw, display)
                        // Non-sort filters preserved.
                        XCTAssertEqual(manga.downloadedFilterRaw, Manga.chapterShowDownloaded)
                        XCTAssertEqual(manga.bookmarkedFilter, .enabledIs)
                    }
                }
            }
        }
    }

    func testSetAllFlagsProducesDisjointFields() {
        // Every field at a non-default value → the OR of all masked constants.
        let flags = SetMangaChapterFlags.setAllFlags(
            unread: Manga.chapterShowRead,
            downloaded: Manga.chapterShowNotDownloaded,
            bookmarked: Manga.chapterShowNotBookmarked,
            sortingMode: Manga.chapterSortingAlphabet,
            sortingDirection: Manga.chapterSortAsc,
            displayMode: Manga.chapterDisplayNumber
        )
        let expected = Manga.chapterShowRead
            | Manga.chapterShowNotDownloaded
            | Manga.chapterShowNotBookmarked
            | Manga.chapterSortingAlphabet
            | Manga.chapterSortAsc
            | Manga.chapterDisplayNumber
        XCTAssertEqual(flags, expected)
    }

    func testDefaultChapterFlagsAreSourceOrderDescending() {
        // chapterFlags = 0 ⇒ source sort with the direction bit clear ⇒ descending.
        let manga = Manga(chapterFlags: 0)
        XCTAssertEqual(manga.sorting, Manga.chapterSortingSource)
        XCTAssertTrue(manga.sortDescending())
        XCTAssertEqual(manga.unreadFilter, .disabled)
    }

    // MARK: - SetMangaChapterFlags transitions

    func testToggleActiveModeFlipsDirection() {
        // Start: NUMBER + ascending. Tap NUMBER → should flip to descending.
        let start = SetMangaChapterFlags.setAllFlags(
            unread: 0, downloaded: 0, bookmarked: 0,
            sortingMode: Manga.chapterSortingNumber,
            sortingDirection: Manga.chapterSortAsc,
            displayMode: Manga.chapterDisplayName
        )
        XCTAssertFalse(Manga(chapterFlags: start).sortDescending())

        let flipped = SetMangaChapterFlags.toggleSortingModeOrFlipOrder(
            current: start, mode: Manga.chapterSortingNumber
        )
        let m = Manga(chapterFlags: flipped)
        XCTAssertEqual(m.sorting, Manga.chapterSortingNumber)   // mode unchanged
        XCTAssertTrue(m.sortDescending())                       // direction flipped

        // Tap again → back to ascending.
        let flippedBack = SetMangaChapterFlags.toggleSortingModeOrFlipOrder(
            current: flipped, mode: Manga.chapterSortingNumber
        )
        XCTAssertFalse(Manga(chapterFlags: flippedBack).sortDescending())
    }

    func testToggleNewModeSetsModeAndResetsToAscending() {
        // Start: SOURCE + descending (default). Tap ALPHABET (a new mode) →
        // sorting becomes ALPHABET and direction resets to ASC.
        let start: Int64 = 0   // source + descending
        let result = SetMangaChapterFlags.toggleSortingModeOrFlipOrder(
            current: start, mode: Manga.chapterSortingAlphabet
        )
        let m = Manga(chapterFlags: result)
        XCTAssertEqual(m.sorting, Manga.chapterSortingAlphabet)
        XCTAssertFalse(m.sortDescending())   // reset to ascending regardless of prior dir
    }

    func testToggleNewModeResetsAscendingEvenWhenPriorWasAscending() {
        // Prior: NUMBER + descending. Switch to UPLOAD_DATE → ASC.
        let start = SetMangaChapterFlags.setAllFlags(
            unread: 0, downloaded: 0, bookmarked: 0,
            sortingMode: Manga.chapterSortingNumber,
            sortingDirection: Manga.chapterSortDesc,
            displayMode: 0
        )
        let result = SetMangaChapterFlags.toggleSortingModeOrFlipOrder(
            current: start, mode: Manga.chapterSortingUploadDate
        )
        let m = Manga(chapterFlags: result)
        XCTAssertEqual(m.sorting, Manga.chapterSortingUploadDate)
        XCTAssertFalse(m.sortDescending())
    }

    func testToggleDoesNotDisturbOtherFlagFields() {
        let start = SetMangaChapterFlags.setAllFlags(
            unread: Manga.chapterShowUnread,
            downloaded: Manga.chapterShowDownloaded,
            bookmarked: Manga.chapterShowBookmarked,
            sortingMode: Manga.chapterSortingNumber,
            sortingDirection: Manga.chapterSortAsc,
            displayMode: Manga.chapterDisplayNumber
        )
        let result = SetMangaChapterFlags.toggleSortingModeOrFlipOrder(
            current: start, mode: Manga.chapterSortingAlphabet
        )
        let m = Manga(chapterFlags: result)
        // Filters + display untouched.
        XCTAssertEqual(m.unreadFilter, .enabledIs)
        XCTAssertEqual(m.downloadedFilterRaw, Manga.chapterShowDownloaded)
        XCTAssertEqual(m.bookmarkedFilter, .enabledIs)
        XCTAssertEqual(m.chapterDisplayModeRaw, Manga.chapterDisplayNumber)
    }

    // MARK: - TriState decode incl. invalid 0x6 fallthrough

    func testUnreadFilterDecode() {
        XCTAssertEqual(Manga(chapterFlags: Manga.chapterShowUnread).unreadFilter, .enabledIs)
        XCTAssertEqual(Manga(chapterFlags: Manga.chapterShowRead).unreadFilter, .enabledNot)
        XCTAssertEqual(Manga(chapterFlags: 0).unreadFilter, .disabled)
        // 0x6 = both bits set → invalid combo → DISABLED fallthrough.
        XCTAssertEqual(Manga.chapterUnreadMask, 0x6)
        XCTAssertEqual(Manga(chapterFlags: 0x6).unreadFilter, .disabled)
    }

    func testBookmarkedFilterDecodeIncludingInvalidCombo() {
        XCTAssertEqual(Manga(chapterFlags: Manga.chapterShowBookmarked).bookmarkedFilter, .enabledIs)
        XCTAssertEqual(Manga(chapterFlags: Manga.chapterShowNotBookmarked).bookmarkedFilter, .enabledNot)
        // 0x60 = both bookmarked bits → invalid → DISABLED.
        XCTAssertEqual(Manga(chapterFlags: 0x60).bookmarkedFilter, .disabled)
    }

    func testTriStateOrdinalsAndCycle() {
        XCTAssertEqual(TriState.disabled.rawValue, 0)
        XCTAssertEqual(TriState.enabledIs.rawValue, 1)
        XCTAssertEqual(TriState.enabledNot.rawValue, 2)
        XCTAssertEqual(TriState.disabled.next(), .enabledIs)
        XCTAssertEqual(TriState.enabledIs.next(), .enabledNot)
        XCTAssertEqual(TriState.enabledNot.next(), .disabled)
    }

    // MARK: - LibrarySort golden vectors (from LibraryFlagsTest.kt)

    func testLibrarySortGoldenVectors() {
        // LastRead+Asc applied-with DateAdded+Asc → 0b01011100.
        let current = LibrarySort(type: .lastRead, direction: .ascending)
        let new = LibrarySort(type: .dateAdded, direction: .ascending)
        XCTAssertEqual(new.applied(to: current.flag), 0b01011100)

        // DateAdded+Asc flag == 0b01011100.
        XCTAssertEqual(LibrarySort(type: .dateAdded, direction: .ascending).flag, 0b01011100)

        // UnreadCount+Desc flag == 0b00001100.
        XCTAssertEqual(LibrarySort(type: .unreadCount, direction: .descending).flag, 0b00001100)

        // default flag == 0b01000000 (Alphabetical + Ascending).
        XCTAssertEqual(LibrarySort.default.flag, 0b01000000)
    }

    func testLibrarySortAppliedOverOldFlagBase() {
        // Mirrors the Kotlin "plus operator with old flag as base" case.
        let currentSort = LibrarySort(type: .unreadCount, direction: .descending)
        XCTAssertEqual(currentSort.flag, 0b00001100)

        let sort = LibrarySort(type: .dateAdded, direction: .ascending)
        let flag = sort.applied(to: currentSort.flag)
        XCTAssertEqual(flag, 0b01011100)
        XCTAssertNotEqual(flag, currentSort.flag)
    }

    // MARK: - ShouldUpdateDbChapter dirty-check

    func testShouldUpdateFalseWhenIdentical() {
        let db = Chapter(
            id: 1, mangaId: 2, sourceOrder: 5, name: "Ch. 1",
            dateUpload: 100, chapterNumber: 1.0, scanlator: "Group"
        )
        let source = db
        XCTAssertFalse(ShouldUpdateDbChapter.shouldUpdate(db: db, source: source))
    }

    func testShouldUpdateTrueOnEachDifferingField() {
        let db = Chapter(
            id: 1, mangaId: 2, sourceOrder: 5, name: "Ch. 1",
            dateUpload: 100, chapterNumber: 1.0, scanlator: "Group",
            memo: .empty
        )

        var scan = db; scan.scanlator = "Other"
        XCTAssertTrue(ShouldUpdateDbChapter.shouldUpdate(db: db, source: scan))

        var name = db; name.name = "Ch. 1 (v2)"
        XCTAssertTrue(ShouldUpdateDbChapter.shouldUpdate(db: db, source: name))

        var date = db; date.dateUpload = 200
        XCTAssertTrue(ShouldUpdateDbChapter.shouldUpdate(db: db, source: date))

        var num = db; num.chapterNumber = 1.5
        XCTAssertTrue(ShouldUpdateDbChapter.shouldUpdate(db: db, source: num))

        var order = db; order.sourceOrder = 6
        XCTAssertTrue(ShouldUpdateDbChapter.shouldUpdate(db: db, source: order))

        var memo = db; memo.memo = .string("changed")
        XCTAssertTrue(ShouldUpdateDbChapter.shouldUpdate(db: db, source: memo))
    }

    func testShouldUpdateIgnoresNonSourceFields() {
        // read/bookmark/lastPageRead/id are NOT part of the dirty compare.
        let db = Chapter(id: 1, read: false, bookmark: false, lastPageRead: 0, name: "Ch. 1")
        var source = db
        source.read = true
        source.bookmark = true
        source.lastPageRead = 42
        XCTAssertFalse(ShouldUpdateDbChapter.shouldUpdate(db: db, source: source))
    }
}
