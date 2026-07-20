import Foundation

/// A single page of a chapter. The core model carries only identity/location.
///
/// Mihon's `Page` also owns mutable download `status`/`progress` StateFlows
/// (`source-api/.../model/Page.kt`); that live state belongs to the reader/
/// download runtime (Lane 3/5), NOT to this platform-agnostic value type. The
/// runtime wraps this in its own observable page-state type.
public struct Page: Sendable, Hashable, Codable {
    public let index: Int
    public var url: String
    public var imageURL: String?

    /// 1-based page number, matching Mihon's `Page.number`.
    public var number: Int { index + 1 }

    public init(index: Int, url: String = "", imageURL: String? = nil) {
        self.index = index
        self.url = url
        self.imageURL = imageURL
    }
}
