import Foundation

/// Persistence boundary. These protocols are defined HERE, in the
/// platform-agnostic core; GRDB-backed implementations live in `MihonData`
/// (ADR-2). Domain logic and tests depend on these protocols and inject a fake,
/// so they run on Windows with no SQLite and no Mac.
///
/// `suspend fun` → `async throws`; Kotlin `Flow<T>` → `AsyncStream<T>`.
/// The domain entities (Manga/Chapter/Category/Track/History) live in `Model/`.

// MARK: Ancillary read-models (minimal placeholders — filled in a later wave)

public struct LibraryManga: Sendable, Hashable {
    public var manga: Manga
    public var unreadCount: Int64
    public var readCount: Int64
    public init(manga: Manga, unreadCount: Int64 = 0, readCount: Int64 = 0) {
        self.manga = manga; self.unreadCount = unreadCount; self.readCount = readCount
    }
}

public struct MangaWithChapterCount: Sendable, Hashable {
    public var manga: Manga
    public var chapterCount: Int64
    public init(manga: Manga, chapterCount: Int64) {
        self.manga = manga; self.chapterCount = chapterCount
    }
}

public struct HistoryWithRelations: Sendable, Hashable {
    public var id: Int64
    public var chapterId: Int64
    public var mangaId: Int64
    public var title: String
    public var readAt: Int64?
    public init(id: Int64, chapterId: Int64, mangaId: Int64, title: String, readAt: Int64?) {
        self.id = id; self.chapterId = chapterId; self.mangaId = mangaId
        self.title = title; self.readAt = readAt
    }
}

// MARK: Repository protocols

public protocol MangaRepository: Sendable {
    func getMangaById(_ id: Int64) async throws -> Manga
    func getMangaByIdAsFlow(_ id: Int64) -> AsyncStream<Manga>
    func getMangaByURLAndSourceId(url: String, sourceId: Int64) async throws -> Manga?
    func getFavorites() async throws -> [Manga]
    func getLibraryManga() async throws -> [LibraryManga]
    func getLibraryMangaAsFlow() -> AsyncStream<[LibraryManga]>
    func getDuplicateLibraryManga(id: Int64, title: String) async throws -> [MangaWithChapterCount]
    func resetViewerFlags() async throws -> Bool
    func setMangaCategories(mangaId: Int64, categoryIds: [Int64]) async throws
    func update(_ update: MangaUpdate) async throws -> Bool
    func updateAll(_ updates: [MangaUpdate]) async throws -> Bool
    func insertNetworkManga(_ manga: [Manga]) async throws -> [Manga]
}

public protocol ChapterRepository: Sendable {
    func addAll(_ chapters: [Chapter]) async throws -> [Chapter]
    func update(_ update: ChapterUpdate) async throws
    func updateAll(_ updates: [ChapterUpdate]) async throws
    func removeChaptersWithIds(_ chapterIds: [Int64]) async throws
    func getChapterByMangaId(mangaId: Int64, applyScanlatorFilter: Bool) async throws -> [Chapter]
    func getBookmarkedChaptersByMangaId(mangaId: Int64) async throws -> [Chapter]
    func getChapterById(_ id: Int64) async throws -> Chapter?
    func getChapterByMangaIdAsFlow(mangaId: Int64, applyScanlatorFilter: Bool) -> AsyncStream<[Chapter]>
    func getChapterByURLAndMangaId(url: String, mangaId: Int64) async throws -> Chapter?
}

public extension ChapterRepository {
    func getChapterByMangaId(mangaId: Int64) async throws -> [Chapter] {
        try await getChapterByMangaId(mangaId: mangaId, applyScanlatorFilter: false)
    }
}

public protocol CategoryRepository: Sendable {
    func get(_ id: Int64) async throws -> Category?
    func getAll() async throws -> [Category]
    func getAllAsFlow() -> AsyncStream<[Category]>
    func getCategoriesByMangaId(mangaId: Int64) async throws -> [Category]
    func insert(_ category: Category) async throws
    func updatePartial(_ update: CategoryUpdate) async throws
    func updatePartial(_ updates: [CategoryUpdate]) async throws
    func updateAllFlags(_ flags: Int64?) async throws
    func delete(categoryId: Int64) async throws
}

public protocol HistoryRepository: Sendable {
    func getHistory(query: String) -> AsyncStream<[HistoryWithRelations]>
    func getLastHistory() async throws -> HistoryWithRelations?
    func getTotalReadDuration() async throws -> Int64
    func getHistoryByMangaId(mangaId: Int64) async throws -> [History]
    func resetHistory(historyId: Int64) async throws
    func resetHistoryByMangaId(mangaId: Int64) async throws
    func deleteAllHistory() async throws -> Bool
    func upsertHistory(_ update: HistoryUpdate) async throws
}

public protocol TrackRepository: Sendable {
    func getTrackById(_ id: Int64) async throws -> Track?
    func getTracksByMangaId(mangaId: Int64) async throws -> [Track]
    func getTracksAsFlow() -> AsyncStream<[Track]>
    func getTracksByMangaIdAsFlow(mangaId: Int64) -> AsyncStream<[Track]>
    func delete(mangaId: Int64, trackerId: Int64) async throws
    func insert(_ track: Track) async throws
    func insertAll(_ tracks: [Track]) async throws
}
