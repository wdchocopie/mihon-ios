import Foundation

/// Source search filters, ported from `source-api/.../model/Filter.kt`.
///
/// Reference semantics on purpose: Kotlin's `Filter<T>` has a **mutable `state`**
/// that the UI edits in place and hands back to `getSearchManga`, and the filter
/// list is heterogeneous (`Filter<*>`). A class hierarchy reproduces both. Marked
/// `@unchecked Sendable` because the mutable state is only touched within a single
/// source's own (single-threaded) call flow — the concrete source runtime (ADR-1,
/// ADR-0-gated) owns that discipline.
open class Filter: @unchecked Sendable {
    public let name: String
    public init(name: String) { self.name = name }
}

/// A non-interactive section header.
public final class HeaderFilter: Filter, @unchecked Sendable {}

/// A visual separator.
public final class SeparatorFilter: Filter, @unchecked Sendable {
    public override init(name: String = "") { super.init(name: name) }
}

/// A single choice among `values`; `state` is the selected index.
open class SelectFilter<V>: Filter, @unchecked Sendable {
    public let values: [V]
    public var state: Int
    public init(name: String, values: [V], state: Int = 0) {
        self.values = values
        self.state = state
        super.init(name: name)
    }
}

/// Free-text input.
open class TextFilter: Filter, @unchecked Sendable {
    public var state: String
    public init(name: String, state: String = "") {
        self.state = state
        super.init(name: name)
    }
}

/// A boolean toggle.
open class CheckBoxFilter: Filter, @unchecked Sendable {
    public var state: Bool
    public init(name: String, state: Bool = false) {
        self.state = state
        super.init(name: name)
    }
}

/// Three-way include/exclude/ignore. State values match Kotlin exactly:
/// ignore=0, include=1, exclude=2.
open class TriStateFilter: Filter, @unchecked Sendable {
    public static let stateIgnore = 0
    public static let stateInclude = 1
    public static let stateExclude = 2

    public var state: Int
    public init(name: String, state: Int = TriStateFilter.stateIgnore) {
        self.state = state
        super.init(name: name)
    }

    public var isIgnored: Bool { state == TriStateFilter.stateIgnore }
    public var isIncluded: Bool { state == TriStateFilter.stateInclude }
    public var isExcluded: Bool { state == TriStateFilter.stateExclude }
}

/// A group of sub-filters; `state` holds the group's values.
open class GroupFilter<V>: Filter, @unchecked Sendable {
    public var state: [V]
    public init(name: String, state: [V]) {
        self.state = state
        super.init(name: name)
    }
}

/// A sort selector over `values`; `state` is the chosen index + direction.
open class SortFilter: Filter, @unchecked Sendable {
    public struct Selection: Sendable, Hashable {
        public let index: Int
        public let ascending: Bool
        public init(index: Int, ascending: Bool) {
            self.index = index
            self.ascending = ascending
        }
    }

    public let values: [String]
    public var state: Selection?
    public init(name: String, values: [String], state: Selection? = nil) {
        self.values = values
        self.state = state
        super.init(name: name)
    }
}

/// An ordered, heterogeneous list of filters — the source's search UI schema.
/// Ports `FilterList.kt`. (Kotlin's deliberate `equals == false` recomposition
/// hack is a Compose concern and intentionally not reproduced.)
public struct FilterList: @unchecked Sendable, RandomAccessCollection {
    public let list: [Filter]

    public init(_ list: [Filter] = []) { self.list = list }
    public init(_ filters: Filter...) { self.list = filters }

    public var startIndex: Int { list.startIndex }
    public var endIndex: Int { list.endIndex }
    public subscript(position: Int) -> Filter { list[position] }
}
