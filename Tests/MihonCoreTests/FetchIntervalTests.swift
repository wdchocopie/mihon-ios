import XCTest
@testable import MihonCore

/// Ports Mihon's upstream `FetchIntervalTest` verbatim (the authoritative oracle,
/// produced by the real Kotlin engine). Reference epoch is
/// `2020-01-01T00:00:00Z`; each chapter sets BOTH `dateFetch` and `dateUpload` to
/// `testTime + offset`. Intervals are asserted against `.init(identifier: "UTC")!`.
final class FetchIntervalTests: XCTestCase {

    // MARK: helpers

    /// Epoch millis of 2020-01-01T00:00:00Z (1577836800 s * 1000).
    private let testTimeMillis: Int64 = 1_577_836_800_000
    private let utc = TimeZone(identifier: "UTC")!

    private func day(_ n: Int) -> Int64 { Int64(n) * 86_400_000 }
    private func hour(_ n: Int) -> Int64 { Int64(n) * 3_600_000 }

    /// Mirrors Kotlin `chapterWithTime`: `newTime = testTime + offset`, applied to
    /// BOTH `dateFetch` and `dateUpload`.
    private func chapterWithTime(offsetMillis: Int64) -> Chapter {
        let t = testTimeMillis + offsetMillis
        return Chapter(dateFetch: t, dateUpload: t)
    }

    private func interval(_ chapters: [Chapter]) -> Int {
        FetchInterval.calculateInterval(chapters, timeZone: utc)
    }

    // MARK: tests (1:1 with FetchIntervalTest.kt)

    func testDefaultIntervalOf7WhenNotEnoughDistinctDays() {
        let withUpload = (1...50).map { _ in chapterWithTime(offsetMillis: day(1)) }
        XCTAssertEqual(interval(withUpload), 7)

        // Same chapters but with dateUpload cleared: fetchDates still collapse to
        // a single distinct day → 7.
        let withoutUpload = withUpload.map { c -> Chapter in
            var c = c; c.dateUpload = 0; return c
        }
        XCTAssertEqual(interval(withoutUpload), 7)
    }

    func testIntervalBasedOnMoreRecentChapters() {
        let oldChapters = (1...5).map { chapterWithTime(offsetMillis: day($0 * 7)) } // 7-day cadence
        let lastUpload = oldChapters.last!.dateUpload                                 // absolute millis, used as offset
        let newChapters = (1...10).map { chapterWithTime(offsetMillis: lastUpload + day($0)) } // 1-day cadence
        XCTAssertEqual(interval(oldChapters + newChapters), 1)
    }

    func testIntervalBasedOnSmallerSubsetWhenVeryFewChapters() {
        let oldChapters = (1...3).map { chapterWithTime(offsetMillis: day($0 * 7)) }
        let lastUpload = oldChapters.last!.dateUpload
        // Significant gap between the two groups.
        let newChapters = (1...3).map { chapterWithTime(offsetMillis: lastUpload + day(365) + day($0 * 7)) }
        XCTAssertEqual(interval(oldChapters + newChapters), 7)
    }

    func testIntervalOf7WhenMultipleChaptersIn1Day() {
        let chapters = (1...10).map { _ in chapterWithTime(offsetMillis: hour(10)) }
        XCTAssertEqual(interval(chapters), 7)
    }

    func testIntervalOf7WhenMultipleChaptersIn2Days() {
        let chapters = (1...2).map { _ in chapterWithTime(offsetMillis: day(1)) }
            + (1...5).map { _ in chapterWithTime(offsetMillis: day(2)) }
        XCTAssertEqual(interval(chapters), 7)
    }

    func testIntervalOf1DayWhenChaptersReleasedEvery1Day() {
        let chapters = (1...20).map { chapterWithTime(offsetMillis: day($0)) }
        XCTAssertEqual(interval(chapters), 1)
    }

    func testIntervalOf1DayWhenDeltaLessThan1Day() {
        let chapters = (1...20).map { chapterWithTime(offsetMillis: hour(15 * $0)) }
        XCTAssertEqual(interval(chapters), 1)
    }

    func testIntervalOf2DaysWhenChaptersReleasedEvery2Days() {
        let chapters = (1...20).map { chapterWithTime(offsetMillis: day(2 * $0)) }
        XCTAssertEqual(interval(chapters), 2)
    }

    func testIntervalFlooredWhenDecimal() {
        let withUpload = (1...5).map { chapterWithTime(offsetMillis: hour(25 * $0)) }
        XCTAssertEqual(interval(withUpload), 1)

        let withoutUpload = withUpload.map { c -> Chapter in
            var c = c; c.dateUpload = 0; return c
        }
        XCTAssertEqual(interval(withoutUpload), 1)
    }

    func testIntervalOf2DaysWhenJustBelowEvery2Days() {
        let chapters = (1...20).map { chapterWithTime(offsetMillis: hour(43 * $0)) }
        XCTAssertEqual(interval(chapters), 2)
    }

    // MARK: floorDiv unit checks (true floor for negatives)

    func testFloorDivTruncatesTowardNegativeInfinity() {
        XCTAssertEqual(FetchInterval.floorDiv(7, 2), 3)
        XCTAssertEqual(FetchInterval.floorDiv(-7, 2), -4)   // truncating / would give -3
        XCTAssertEqual(FetchInterval.floorDiv(7, -2), -4)
        XCTAssertEqual(FetchInterval.floorDiv(-7, -2), 3)
        XCTAssertEqual(FetchInterval.floorDiv(6, 2), 3)     // exact division, no adjustment
    }
}
