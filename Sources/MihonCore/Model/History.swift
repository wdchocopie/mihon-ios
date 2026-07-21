import Foundation

/// A reading-history entry, ported from `domain/.../history/model/History.kt`.
/// `readAt` is nullable (never-read). Modeled as epoch-millis `Int64?` to keep the
/// core Foundation-`Date`-free at the boundary. `create()` defaults are all -1/nil.
public struct History: Sendable, Hashable, Identifiable, Codable {
    public var id: Int64
    public var chapterId: Int64
    public var readAt: Int64?          // epoch millis; nil = never read
    public var readDuration: Int64

    public init(id: Int64 = -1, chapterId: Int64 = -1, readAt: Int64? = nil, readDuration: Int64 = -1) {
        self.id = id; self.chapterId = chapterId; self.readAt = readAt; self.readDuration = readDuration
    }
}

/// Upsert DTO for history.
public struct HistoryUpdate: Sendable, Hashable {
    public var chapterId: Int64
    public var readAt: Int64?
    public var sessionReadDuration: Int64

    public init(chapterId: Int64, readAt: Int64?, sessionReadDuration: Int64) {
        self.chapterId = chapterId; self.readAt = readAt; self.sessionReadDuration = sessionReadDuration
    }
}
