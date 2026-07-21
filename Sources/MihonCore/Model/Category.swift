import Foundation

/// A library category, ported from `domain/.../category/model/Category.kt`.
/// `flags: Int64` packs the per-category `LibrarySort` (see `LibrarySort`).
public struct Category: Sendable, Hashable, Identifiable, Codable {
    public var id: Int64
    public var name: String
    public var order: Int64
    public var flags: Int64

    /// The system "Uncategorized" category id.
    public static let uncategorizedID: Int64 = 0

    public var isSystemCategory: Bool { id == Category.uncategorizedID }

    public init(id: Int64, name: String, order: Int64 = 0, flags: Int64 = 0) {
        self.id = id; self.name = name; self.order = order; self.flags = flags
    }
}

/// Partial-update DTO for a category.
public struct CategoryUpdate: Sendable, Hashable {
    public var id: Int64
    public var name: String?
    public var order: Int64?
    public var flags: Int64?

    public init(id: Int64) { self.id = id }
}
