import XCTest
@testable import MihonCore

/// Structural tests for `ChapterSort`. Deliberately avoids asserting an exact
/// collation golden (locale collation is platform-dependent) — instead pins the
/// behavioural invariants that cross the DB/backup boundary: default direction,
/// the inverted SOURCE case, direction-bit reversal, stable tiebreak under both
/// directions, and NaN-safety.
final class ChapterSortTests: XCTestCase {

    // MARK: helpers

    /// Build a manga whose `chapterFlags` select `sorting` + direction.
    /// `ascending == true` sets the direction bit (ASC); false leaves it clear
    /// (DESC — the persisted default).
    private func makeManga(sorting: Int64, ascending: Bool) -> Manga {
        let dir = ascending ? Manga.chapterSortAsc : Manga.chapterSortDesc
        return Manga(chapterFlags: sorting | dir)
    }

    private func chapter(id: Int64, sourceOrder: Int64 = 0, number: Double = 0, name: String = "") -> Chapter {
        Chapter(id: id, sourceOrder: sourceOrder, name: name, chapterNumber: number)
    }

    // MARK: tests

    func testDefaultFlagsSortAscendingSourceOrder() {
        // chapterFlags == 0 ⇒ SOURCE mode, direction bit clear ⇒ sortDescending()
        // == true ⇒ (inverted) natural ASCENDING source order.
        let manga = Manga()   // chapterFlags defaults to 0
        XCTAssertTrue(manga.sortDescending())
        XCTAssertEqual(manga.sorting, Manga.chapterSortingSource)

        let input = [
            chapter(id: 10, sourceOrder: 2),
            chapter(id: 11, sourceOrder: 0),
            chapter(id: 12, sourceOrder: 1),
        ]
        let sorted = sortedChapters(input, for: manga)
        XCTAssertEqual(sorted.map(\.sourceOrder), [0, 1, 2])
    }

    func testSourceCaseInvertsRelativeToNumber() {
        // Same direction flag; SOURCE and NUMBER must yield OPPOSITE comparator signs.
        let c1 = chapter(id: 1, sourceOrder: 0, number: 0.0)
        let c2 = chapter(id: 2, sourceOrder: 1, number: 1.0)

        let sourceDesc = getChapterSort(makeManga(sorting: Manga.chapterSortingSource, ascending: false))
        let numberDesc = getChapterSort(makeManga(sorting: Manga.chapterSortingNumber, ascending: false))

        let s = sourceDesc(c1, c2)
        let n = numberDesc(c1, c2)
        XCTAssertNotEqual(s, 0)
        XCTAssertNotEqual(n, 0)
        // Opposite signs.
        XCTAssertTrue((s < 0) != (n < 0), "SOURCE must invert relative to NUMBER (s=\(s), n=\(n))")
    }

    func testFlippingDirectionBitReversesOrder() {
        let input = [
            chapter(id: 1, number: 3.0),
            chapter(id: 2, number: 1.0),
            chapter(id: 3, number: 2.0),
        ]
        let asc = sortedChapters(input, for: makeManga(sorting: Manga.chapterSortingNumber, ascending: true))
        let desc = sortedChapters(input, for: makeManga(sorting: Manga.chapterSortingNumber, ascending: false))

        XCTAssertEqual(asc.map(\.chapterNumber), [1.0, 2.0, 3.0])
        XCTAssertEqual(desc.map(\.chapterNumber), [3.0, 2.0, 1.0])
    }

    func testDuplicateKeyStabilityUnderBothDirections() {
        // All equal keys — output must preserve INPUT order regardless of direction.
        let input = [
            chapter(id: 100, number: 5.0),
            chapter(id: 101, number: 5.0),
            chapter(id: 102, number: 5.0),
            chapter(id: 103, number: 5.0),
        ]
        let expectedIds: [Int64] = [100, 101, 102, 103]

        let asc = sortedChapters(input, for: makeManga(sorting: Manga.chapterSortingNumber, ascending: true))
        let desc = sortedChapters(input, for: makeManga(sorting: Manga.chapterSortingNumber, ascending: false))

        XCTAssertEqual(asc.map(\.id), expectedIds, "stable tiebreak (ascending): input order preserved")
        XCTAssertEqual(desc.map(\.id), expectedIds, "stable tiebreak (descending): input order preserved")
    }

    func testNaNChapterNumberDoesNotCrash() {
        let input = [
            chapter(id: 1, number: 2.0),
            chapter(id: 2, number: .nan),
            chapter(id: 3, number: 1.0),
            chapter(id: 4, number: .nan),
        ]
        // Must not trap on the inconsistent-ordering path.
        let asc = sortedChapters(input, for: makeManga(sorting: Manga.chapterSortingNumber, ascending: true))
        let desc = sortedChapters(input, for: makeManga(sorting: Manga.chapterSortingNumber, ascending: false))
        XCTAssertEqual(asc.count, 4)
        XCTAssertEqual(desc.count, 4)
    }

    func testAlphabetModeSortsAscendingAndDescending() {
        // Structural only — not asserting exact collation, just that the two
        // directions are reverses of each other for clearly-ordered names.
        let input = [
            chapter(id: 1, name: "Chapter C"),
            chapter(id: 2, name: "Chapter A"),
            chapter(id: 3, name: "Chapter B"),
        ]
        let asc = sortedChapters(input, for: makeManga(sorting: Manga.chapterSortingAlphabet, ascending: true))
        let desc = sortedChapters(input, for: makeManga(sorting: Manga.chapterSortingAlphabet, ascending: false))
        XCTAssertEqual(asc.map(\.name), desc.map(\.name).reversed())
    }
}
