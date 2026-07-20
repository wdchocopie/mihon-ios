import XCTest
@testable import MihonCore

final class ModelTests: XCTestCase {

    func testMangaStatusRawValuesAreStable() {
        // These are persisted and cross the backup boundary — pin them.
        XCTAssertEqual(MangaStatus.unknown.rawValue, 0)
        XCTAssertEqual(MangaStatus.ongoing.rawValue, 1)
        XCTAssertEqual(MangaStatus.completed.rawValue, 2)
        XCTAssertEqual(MangaStatus.licensed.rawValue, 3)
        XCTAssertEqual(MangaStatus.publishingFinished.rawValue, 4)
        XCTAssertEqual(MangaStatus.cancelled.rawValue, 5)
        XCTAssertEqual(MangaStatus.onHiatus.rawValue, 6)
    }

    func testUpdateStrategyRawValuesAreStable() {
        XCTAssertEqual(UpdateStrategy.alwaysUpdate.rawValue, 0)
        XCTAssertEqual(UpdateStrategy.onlyFetchOnce.rawValue, 1)
    }

    func testPageNumberIsOneBased() {
        XCTAssertEqual(Page(index: 0).number, 1)
        XCTAssertEqual(Page(index: 41).number, 42)
    }

    func testSMangaRoundTripsThroughCodable() throws {
        let manga = SManga(
            url: "/manga/1",
            title: "Test",
            status: .ongoing,
            genre: ["Action", "Comedy"],
            updateStrategy: .onlyFetchOnce,
            initialized: true
        )
        let data = try JSONEncoder().encode(manga)
        let decoded = try JSONDecoder().decode(SManga.self, from: data)
        XCTAssertEqual(manga, decoded)
    }
}
