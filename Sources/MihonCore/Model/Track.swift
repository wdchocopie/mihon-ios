import Foundation

/// A tracker binding, ported from `domain/.../track/model/Track.kt`. Has no
/// `create()` in Mihon — every field is required at construction. `status`/`score`
/// are numeric codes (not enums) here. `libraryId` is nullable.
public struct Track: Sendable, Hashable, Identifiable, Codable {
    public var id: Int64
    public var mangaId: Int64
    public var trackerId: Int64
    public var remoteId: Int64
    public var libraryId: Int64?
    public var title: String
    public var lastChapterRead: Double
    public var totalChapters: Int64
    public var status: Int64
    public var score: Double
    public var remoteUrl: String
    public var startDate: Int64
    public var finishDate: Int64
    public var `private`: Bool

    public init(
        id: Int64, mangaId: Int64, trackerId: Int64, remoteId: Int64,
        libraryId: Int64?, title: String, lastChapterRead: Double,
        totalChapters: Int64, status: Int64, score: Double, remoteUrl: String,
        startDate: Int64, finishDate: Int64, private: Bool
    ) {
        self.id = id; self.mangaId = mangaId; self.trackerId = trackerId
        self.remoteId = remoteId; self.libraryId = libraryId; self.title = title
        self.lastChapterRead = lastChapterRead; self.totalChapters = totalChapters
        self.status = status; self.score = score; self.remoteUrl = remoteUrl
        self.startDate = startDate; self.finishDate = finishDate; self.private = `private`
    }
}
