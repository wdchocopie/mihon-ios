import Foundation

/// Catalogue-browsing source. Ported from `CatalogueSource.kt`, which adds a
/// required `lang` to `Source` and (in Kotlin) bridged the deprecated Rx API —
/// dropped here, since the modern async API is the only one ported.
public protocol CatalogueSource: Source {
    /// ISO 639-1 language code (or "all").
    var lang: String { get }
}

/// A factory that produces several sources at runtime (`SourceFactory.kt`) —
/// e.g. one implementation fanned out across many languages.
public protocol SourceFactory: Sendable {
    func createSources() -> [Source]
}

/// Marker: a source that needs no traffic throttling (self-hosted). `UnmeteredSource.kt`.
public protocol UnmeteredSource: Source {}

/// A source with its own settings screen (`ConfigurableSource.kt`). The Android
/// `SharedPreferences` / `PreferenceScreen` wiring is platform UI and deferred;
/// the contract here is the per-source preference key and the setup hook, to be
/// realized against the iOS settings surface and the source runtime (ADR-1).
public protocol ConfigurableSource: Source {
    /// Builds the source's settings UI. The concrete `PreferenceScreen`-equivalent
    /// type lands with the runtime; typed as `Any` at the contract level for now.
    func setupPreferenceScreen(_ screen: Any)
}

public extension ConfigurableSource {
    /// Per-source preferences namespace, matching Kotlin's `"source_$id"`.
    var preferenceKey: String { "source_\(id)" }
}

/// A source that can resolve a URL to an SManga/SChapter (deep links).
/// Ports `ResolvableSource.kt`.
public protocol ResolvableSource: Source {
    func getUriType(_ uri: String) -> UriType
    func getManga(uri: String) async throws -> SManga?
    func getChapter(uri: String) async throws -> SChapter?
}

/// What a resolvable URI points at.
public enum UriType: Sendable, Hashable {
    case manga
    case chapter
    case unknown
}
