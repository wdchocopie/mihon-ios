import Foundation

/// The extension contract, ported from Mihon's `Source`/`CatalogueSource`
/// (`source-api/.../source/Source.kt`). This protocol is **platform-agnostic on
/// purpose**: the concrete implementations live in `MihonSources` (the
/// JavaScriptCore runtime, ADR-1) behind this boundary, so everything that
/// consumes a source — library update logic, the reader's page loader, browse —
/// depends only on this protocol and stays testable on Windows with a fake.
///
/// Mihon's deprecated Rx `fetch*` variants are intentionally dropped; only the
/// modern suspend API is ported (here as `async`).
public protocol Source: Sendable {
    /// Unique, stable. Produced by `SourceID.generate` for HTTP sources.
    var id: Int64 { get }
    var name: String { get }
    /// ISO 639-1 language code, or "all" / "" for language-agnostic sources.
    var lang: String { get }
    var supportsLatest: Bool { get }

    func getFilterList() -> FilterList

    func getPopularManga(page: Int) async throws -> MangasPage
    func getLatestUpdates(page: Int) async throws -> MangasPage
    func getSearchManga(page: Int, query: String, filters: FilterList) async throws -> MangasPage

    func getMangaDetails(_ manga: SManga) async throws -> SManga
    func getChapterList(_ manga: SManga) async throws -> [SChapter]
    func getPageList(_ chapter: SChapter) async throws -> [Page]
}

public extension Source {
    var lang: String { "" }
    func getFilterList() -> FilterList { FilterList() }
}

/// One page of catalogue results plus whether more exist.
public struct MangasPage: Sendable, Hashable, Codable {
    public var mangas: [SManga]
    public var hasNextPage: Bool

    public init(mangas: [SManga], hasNextPage: Bool) {
        self.mangas = mangas
        self.hasNextPage = hasNextPage
    }
}

// `FilterList` and the `Filter` hierarchy now live in `Filter.swift`.
