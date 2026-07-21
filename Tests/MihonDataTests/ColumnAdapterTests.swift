import XCTest
@testable import MihonData
import MihonCore

final class ColumnAdapterTests: XCTestCase {

    // MARK: StringList (genre) — the ", " separator is backup-boundary-critical

    func testGenreRoundTrip() {
        XCTAssertEqual(StringListColumnAdapter.encode(["Action", "Comedy"]), "Action, Comedy")
        XCTAssertEqual(StringListColumnAdapter.decode("Action, Comedy"), ["Action", "Comedy"])
    }

    func testGenreEmptyStringDecodesToEmptyList() {
        // Mihon: empty string → emptyList (NOT [""]).
        XCTAssertEqual(StringListColumnAdapter.decode(""), [])
        XCTAssertEqual(StringListColumnAdapter.encode([]), "")
    }

    func testGenreSingleElement() {
        XCTAssertEqual(StringListColumnAdapter.encode(["Action"]), "Action")
        XCTAssertEqual(StringListColumnAdapter.decode("Action"), ["Action"])
    }

    func testGenreSeparatorIsExactlyCommaSpace() {
        // A genre value that itself contains ", " splits — this is Mihon's exact
        // (bug-compatible) behavior, pinned so a "smarter" separator never sneaks in.
        XCTAssertEqual(StringListColumnAdapter.decode("Sci, Fi"), ["Sci", "Fi"])
        XCTAssertEqual(StringListColumnAdapter.separator, ", ")
    }

    // MARK: UpdateStrategy

    func testUpdateStrategyRoundTrip() {
        XCTAssertEqual(UpdateStrategyColumnAdapter.encode(.alwaysUpdate), 0)
        XCTAssertEqual(UpdateStrategyColumnAdapter.encode(.onlyFetchOnce), 1)
        XCTAssertEqual(UpdateStrategyColumnAdapter.decode(0), .alwaysUpdate)
        XCTAssertEqual(UpdateStrategyColumnAdapter.decode(1), .onlyFetchOnce)
    }

    func testUpdateStrategyUnknownFallsBackToAlwaysUpdate() {
        // Mirrors Kotlin getOrElse { ALWAYS_UPDATE }.
        XCTAssertEqual(UpdateStrategyColumnAdapter.decode(99), .alwaysUpdate)
        XCTAssertEqual(UpdateStrategyColumnAdapter.decode(-1), .alwaysUpdate)
    }

    // MARK: Boolean

    func testBooleanAdapter() {
        XCTAssertEqual(BooleanColumnAdapter.encode(true), 1)
        XCTAssertEqual(BooleanColumnAdapter.encode(false), 0)
        XCTAssertTrue(BooleanColumnAdapter.decode(1))
        XCTAssertFalse(BooleanColumnAdapter.decode(0))
        XCTAssertTrue(BooleanColumnAdapter.decode(2)) // any non-zero is true
    }

    // MARK: Memo (JSONValue ⟷ bytes)

    func testMemoRoundTrip() throws {
        let memo = JSONValue.object(["k": .string("v"), "n": .int(42)])
        let bytes = try MemoColumnAdapter.encode(memo)
        XCTAssertEqual(try MemoColumnAdapter.decode(bytes), memo)
    }

    func testMemoEmptyBytesDecodesToEmptyObject() throws {
        XCTAssertEqual(try MemoColumnAdapter.decode(MemoColumnAdapter.emptyBytes), .object([:]))
    }
}
