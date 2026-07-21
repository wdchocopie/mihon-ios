import XCTest
@testable import MihonCore

/// Golden-vector port of Mihon's upstream `ChapterRecognitionTest.kt`. Every
/// `assertChapter(title, name, expected)` case is reproduced verbatim — these are
/// the authoritative oracle produced by the real Kotlin regex engine. Runs on
/// Windows/Linux with `swift test`.
final class ChapterRecognitionTests: XCTestCase {

    private func assertChapter(
        _ mangaTitle: String,
        _ name: String,
        _ expected: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = ChapterRecognition.parseChapterNumber(mangaTitle: mangaTitle, chapterName: name)
        XCTAssertEqual(actual, expected, accuracy: 0.0001, "\(mangaTitle) / \(name)", file: file, line: line)
    }

    func testBasicChPrefix() {
        assertChapter("Mokushiroku Alice", "Mokushiroku Alice Vol.1 Ch.4: Misrepresentation", 4.0)
    }

    func testBasicChPrefixWithSpaceAfterPeriod() {
        assertChapter("Mokushiroku Alice", "Mokushiroku Alice Vol. 1 Ch. 4: Misrepresentation", 4.0)
    }

    func testBasicChPrefixWithDecimal() {
        assertChapter("Mokushiroku Alice", "Mokushiroku Alice Vol.1 Ch.4.1: Misrepresentation", 4.1)
        assertChapter("Mokushiroku Alice", "Mokushiroku Alice Vol.1 Ch.4.4: Misrepresentation", 4.4)
    }

    func testBasicChPrefixWithAlphaPostfix() {
        assertChapter("Mokushiroku Alice", "Mokushiroku Alice Vol.1 Ch.4.a: Misrepresentation", 4.1)
        assertChapter("Mokushiroku Alice", "Mokushiroku Alice Vol.1 Ch.4.b: Misrepresentation", 4.2)
        assertChapter("Mokushiroku Alice", "Mokushiroku Alice Vol.1 Ch.4.extra: Misrepresentation", 4.99)
    }

    func testNameContainingOneNumber() {
        assertChapter("Bleach", "Bleach 567 Down With Snowwhite", 567.0)
    }

    func testNameContainingOneNumberAndDecimal() {
        assertChapter("Bleach", "Bleach 567.1 Down With Snowwhite", 567.1)
        assertChapter("Bleach", "Bleach 567.4 Down With Snowwhite", 567.4)
    }

    func testNameContainingOneNumberAndAlpha() {
        assertChapter("Bleach", "Bleach 567.a Down With Snowwhite", 567.1)
        assertChapter("Bleach", "Bleach 567.b Down With Snowwhite", 567.2)
        assertChapter("Bleach", "Bleach 567.extra Down With Snowwhite", 567.99)
    }

    func testChapterContainingMangaTitleAndNumber() {
        assertChapter("Solanin", "Solanin 028 Vol. 2", 28.0)
    }

    func testChapterContainingMangaTitleAndNumberDecimal() {
        assertChapter("Solanin", "Solanin 028.1 Vol. 2", 28.1)
        assertChapter("Solanin", "Solanin 028.4 Vol. 2", 28.4)
    }

    func testChapterContainingMangaTitleAndNumberAlpha() {
        assertChapter("Solanin", "Solanin 028.a Vol. 2", 28.1)
        assertChapter("Solanin", "Solanin 028.b Vol. 2", 28.2)
        assertChapter("Solanin", "Solanin 028.extra Vol. 2", 28.99)
    }

    func testExtremeCase() {
        assertChapter("Onepunch-Man", "Onepunch-Man Punch Ver002 028", 28.0)
    }

    func testExtremeCaseWithDecimal() {
        assertChapter("Onepunch-Man", "Onepunch-Man Punch Ver002 028.1", 28.1)
        assertChapter("Onepunch-Man", "Onepunch-Man Punch Ver002 028.4", 28.4)
    }

    func testExtremeCaseWithAlpha() {
        assertChapter("Onepunch-Man", "Onepunch-Man Punch Ver002 028.a", 28.1)
        assertChapter("Onepunch-Man", "Onepunch-Man Punch Ver002 028.b", 28.2)
        assertChapter("Onepunch-Man", "Onepunch-Man Punch Ver002 028.extra", 28.99)
    }

    func testChapterContainingDotV2() {
        assertChapter("random", "Vol.1 Ch.5v.2: Alones", 5.0)
    }

    func testNumberInMangaTitle() {
        assertChapter("Ayame 14", "Ayame 14 1 - The summer of 14", 1.0)
    }

    func testSpaceBetweenChX() {
        assertChapter("Mokushiroku Alice", "Mokushiroku Alice Vol.1 Ch. 4: Misrepresentation", 4.0)
    }

    func testChapterTitleWithChSubstring() {
        assertChapter("Ayame 14", "Vol.1 Ch.1: March 25 (First Day Cohabiting)", 1.0)
    }

    func testChapterContainingMultipleZeros() {
        assertChapter("random", "Vol.001 Ch.003: Kaguya Doesn't Know Much", 3.0)
    }

    func testChapterWithVersionBeforeNumber() {
        assertChapter("Onepunch-Man", "Onepunch-Man Punch Ver002 086 : Creeping Darkness [3]", 86.0)
    }

    func testVersionAttachedToChapterNumber() {
        assertChapter("Ansatsu Kyoushitsu", "Ansatsu Kyoushitsu 011v002: Assembly Time", 11.0)
    }

    func testNumberAfterMangaTitleWithChapterInChapterTitleCase() {
        assertChapter("Tokyo ESP", "Tokyo ESP 027: Part 002: Chapter 001", 27.0)
    }

    func testNumberAfterUnwantedTag() {
        assertChapter("One-punch Man", "Mag Version 195.5", 195.5)
    }

    func testUnparseableChapter() {
        assertChapter("random", "Foo", -1.0)
    }

    func testChapterWithTimeInTitle() {
        assertChapter("random", "Fairy Tail 404: 00:00", 404.0)
    }

    func testChapterWithAlphaWithoutDot() {
        assertChapter("random", "Asu No Yoichi 19a", 19.1)
    }

    func testChapterTitleContainingExtraAndVol() {
        assertChapter("Fairy Tail", "Fairy Tail 404.extravol002", 404.99)
        assertChapter("Fairy Tail", "Fairy Tail 404 extravol002", 404.99)
    }

    func testChapterTitleContainingOmakeAndVol() {
        assertChapter("Fairy Tail", "Fairy Tail 404.omakevol002", 404.98)
        assertChapter("Fairy Tail", "Fairy Tail 404 omakevol002", 404.98)
    }

    func testChapterTitleContainingSpecialAndVol() {
        assertChapter("Fairy Tail", "Fairy Tail 404.specialvol002", 404.97)
        assertChapter("Fairy Tail", "Fairy Tail 404 specialvol002", 404.97)
    }

    func testChapterTitleContainingCommas() {
        assertChapter("One Piece", "One Piece 300,a", 300.1)
        assertChapter("One Piece", "One Piece Ch,123,extra", 123.99)
        assertChapter("One Piece", "One Piece the sunny, goes swimming 024,005", 24.005)
    }

    func testChapterTitleContainingHyphens() {
        assertChapter("Solo Leveling", "ch 122-a", 122.1)
        assertChapter("Solo Leveling", "Solo Leveling Ch.123-extra", 123.99)
        assertChapter("Solo Leveling", "Solo Leveling, 024-005", 24.005)
        assertChapter("Solo Leveling", "Ch.191-200 Read Online", 191.200)
    }

    func testChaptersContainingSeason() {
        assertChapter("D.I.C.E", "D.I.C.E[Season 001] Ep. 007", 7.0)
    }

    func testChaptersInFormatSxChapterXx() {
        assertChapter("The Gamer", "S3 - Chapter 20", 20.0)
    }

    func testChaptersEndingWithS() {
        assertChapter("One Outs", "One Outs 001", 1.0)
    }

    func testChaptersContainingOrdinals() {
        let mangaTitle = "The Sister of the Woods with a Thousand Young"
        assertChapter(mangaTitle, "The 1st Night", 1.0)
        assertChapter(mangaTitle, "The 2nd Night", 2.0)
        assertChapter(mangaTitle, "The 3rd Night", 3.0)
        assertChapter(mangaTitle, "The 4th Night", 4.0)
    }
}
