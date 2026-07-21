import XCTest
@testable import MihonCore

final class FilterTests: XCTestCase {

    func testTriStateConstantsAndHelpers() {
        XCTAssertEqual(TriStateFilter.stateIgnore, 0)
        XCTAssertEqual(TriStateFilter.stateInclude, 1)
        XCTAssertEqual(TriStateFilter.stateExclude, 2)

        let f = TriStateFilter(name: "Completed")
        XCTAssertTrue(f.isIgnored)          // default
        f.state = TriStateFilter.stateInclude
        XCTAssertTrue(f.isIncluded)
        XCTAssertFalse(f.isIgnored)
        f.state = TriStateFilter.stateExclude
        XCTAssertTrue(f.isExcluded)
    }

    func testSelectFilterHoldsValuesAndMutableIndex() {
        let f = SelectFilter(name: "Sort", values: ["A", "B", "C"])
        XCTAssertEqual(f.values, ["A", "B", "C"])
        XCTAssertEqual(f.state, 0)
        f.state = 2
        XCTAssertEqual(f.state, 2)
    }

    func testTextAndCheckBoxState() {
        let text = TextFilter(name: "Author")
        XCTAssertEqual(text.state, "")
        text.state = "Oda"
        XCTAssertEqual(text.state, "Oda")

        let cb = CheckBoxFilter(name: "NSFW")
        XCTAssertFalse(cb.state)
        cb.state = true
        XCTAssertTrue(cb.state)
    }

    func testSortSelection() {
        let f = SortFilter(name: "Order", values: ["Popular", "Latest"],
                           state: .init(index: 1, ascending: false))
        XCTAssertEqual(f.state?.index, 1)
        XCTAssertEqual(f.state?.ascending, false)
        XCTAssertEqual(f.values.count, 2)
    }

    func testGroupFilter() {
        let g = GroupFilter(name: "Genres", state: [
            CheckBoxFilter(name: "Action"), CheckBoxFilter(name: "Comedy"),
        ])
        XCTAssertEqual(g.state.count, 2)
        XCTAssertEqual(g.name, "Genres")
    }

    func testFilterListIsHeterogeneousCollection() {
        let list = FilterList(
            HeaderFilter(name: "Filters"),
            TriStateFilter(name: "Completed"),
            TextFilter(name: "Author"),
            SortFilter(name: "Order", values: ["A", "B"])
        )
        XCTAssertEqual(list.count, 4)
        XCTAssertEqual(list.first?.name, "Filters")
        XCTAssertTrue(list[1] is TriStateFilter)
        XCTAssertTrue(list.contains { $0 is SortFilter })
    }

    func testEmptyFilterList() {
        XCTAssertTrue(FilterList().isEmpty)
    }
}
