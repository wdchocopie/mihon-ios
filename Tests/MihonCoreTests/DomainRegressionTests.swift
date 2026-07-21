import XCTest
@testable import MihonCore

/// Regression tests for the CONFIRMED cross-engine divergences found by the
/// Phase-4 adversarial verification — cases Mihon's own (ASCII-only) golden
/// vectors never exercise. Each would silently diverge before its fix.
final class DomainRegressionTests: XCTestCase {

    // MARK: ChapterRecognition — Java-vs-ICU regex semantics

    /// `\b` is ASCII in Java, Unicode-aware in ICU. A non-ASCII prefix (common in
    /// a manga app) must NOT suppress the volume-tag strip. "봄vol1 5" → strip
    /// "vol1" → 5.0 (ICU `\b` would leave it and return 1.0).
    func testNonAsciiPrefixedVolumeTagIsStripped() {
        XCTAssertEqual(ChapterRecognition.parseChapterNumber(mangaTitle: "", chapterName: "봄vol1 5"), 5.0, accuracy: 0.0001)
    }

    /// `\s` is ASCII in Java, matches NBSP in ICU. A non-breaking space before
    /// "extra" must NOT be glued (which would wrongly yield .99). "12\u{00A0}extra" → 12.0.
    func testNbspBeforeKeywordNotGlued() {
        XCTAssertEqual(
            ChapterRecognition.parseChapterNumber(mangaTitle: "", chapterName: "One Piece 12\u{00A0}extra"),
            12.0, accuracy: 0.0001
        )
        // A regular ASCII space still glues (matches Mihon) → 12.99.
        XCTAssertEqual(
            ChapterRecognition.parseChapterNumber(mangaTitle: "", chapterName: "One Piece 12 extra"),
            12.99, accuracy: 0.0001
        )
    }

    // MARK: ChapterSort — Collator PRIMARY (lexical) vs numeric ordering

    /// Kotlin's `Collator(PRIMARY)` compares "Chapter 2" vs "Chapter 10"
    /// lexically ('1' < '2'), so "Chapter 10" sorts FIRST. `localizedStandardCompare`
    /// would do numeric ordering (2 before 10) — inverted.
    func testAlphabetSortIsLexicalNotNumeric() {
        let manga = Manga(chapterFlags: Manga.chapterSortingAlphabet | Manga.chapterSortAsc)
        let chapters = [Chapter(name: "Chapter 2"), Chapter(name: "Chapter 10")]
        let sorted = sortedChapters(chapters, for: manga)
        XCTAssertEqual(sorted.map(\.name), ["Chapter 10", "Chapter 2"])
    }

    // MARK: JSONValue (memo) — lossless integers & content-based inequality

    func testLargeIntegerMemoPreservedAndDistinct() {
        // 2^53+1 and 2^53 both round to the same Double — must stay distinct as Int.
        XCTAssertNotEqual(JSONValue.int(9_007_199_254_740_993), JSONValue.int(9_007_199_254_740_992))
    }

    func testIntAndDoubleAreNotEqual() {
        // Matches kotlinx JsonPrimitive content equality: "1" != "1.0".
        XCTAssertNotEqual(JSONValue.int(1), JSONValue.number(1.0))
    }

    func testLargeIntegerMemoRoundTrips() throws {
        let original = JSONValue.object(["id": .int(9_007_199_254_740_993)])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    /// The memo dirty-check drives whether a chapter row is refreshed. Two large
    /// integer memos that differ must be seen as different (Double would collapse them).
    func testShouldUpdateDetectsLargeIntegerMemoDifference() {
        let db = Chapter(name: "c", chapterNumber: 1, memo: .object(["id": .int(9_007_199_254_740_993)]))
        let source = Chapter(name: "c", chapterNumber: 1, memo: .object(["id": .int(9_007_199_254_740_992)]))
        XCTAssertTrue(ShouldUpdateDbChapter.shouldUpdate(db: db, source: source))
    }
}
