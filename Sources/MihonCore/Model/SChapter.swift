import Foundation

/// A chapter as returned by a source. Mirrors Mihon's `SChapter`
/// (`source-api/.../model/SChapter.kt`) as a Swift value type.
public struct SChapter: Sendable, Hashable, Codable {
    public var url: String
    public var name: String
    /// Source-declared chapter number; `-1` means "unknown / not parsed".
    public var chapterNumber: Float
    public var scanlator: String?
    /// Upload time, epoch milliseconds (Mihon uses `Long` millis).
    public var dateUpload: Int64

    // TODO(port): `memo: JsonObject`.

    public init(
        url: String,
        name: String,
        chapterNumber: Float = -1,
        scanlator: String? = nil,
        dateUpload: Int64 = 0
    ) {
        self.url = url
        self.name = name
        self.chapterNumber = chapterNumber
        self.scanlator = scanlator
        self.dateUpload = dateUpload
    }
}
