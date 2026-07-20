import Foundation

/// Persistence boundary. These protocols are defined HERE, in the
/// platform-agnostic core; the GRDB-backed implementations live in `MihonData`
/// (ADR-2). Domain logic and tests depend on these protocols and inject a fake,
/// so they run on Windows with no SQLite and no Mac.
///
/// This is a deliberately minimal seed — enough to establish the boundary. The
/// full repository surface (chapters, categories, history, tracks, updates,
/// downloads) is ported per-module in later waves, each against the real
/// SQLDelight `.sq` queries as the behavioral spec.

/// A library manga (domain entity). Distinct from `SManga` (the source model):
/// this is the persisted, library-side representation carrying local state.
///
/// TODO(port): fill out the remaining columns from `mangas.sq` (favorite flags,
/// viewer/chapter bit-flags, next_update, version/is_syncing sync counters,
/// dates). Kept minimal here to establish the type, not to be complete.
public struct Manga: Sendable, Hashable, Identifiable, Codable {
    public let id: Int64
    public var source: Int64
    public var url: String
    public var title: String
    public var favorite: Bool

    public init(id: Int64, source: Int64, url: String, title: String, favorite: Bool) {
        self.id = id
        self.source = source
        self.url = url
        self.title = title
        self.favorite = favorite
    }
}

public protocol MangaRepository: Sendable {
    func getMangaByID(_ id: Int64) async throws -> Manga?
    func getMangaByURLAndSource(url: String, source: Int64) async throws -> Manga?
    func getFavorites() async throws -> [Manga]
}
