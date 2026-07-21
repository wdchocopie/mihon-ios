import Foundation

/// Three-way filter, ported from Mihon's `TriState`
/// (`core/common/.../preference/TriState.kt`).
///
/// ⚠️ These ordinals (0/1/2) are the IN-MEMORY representation only. The values
/// persisted in `chapterFlags` are the `CHAPTER_SHOW_*` bit constants (0x2/0x4…),
/// NOT these ordinals — see `Manga`.
public enum TriState: Int, Sendable, Hashable, Codable, CaseIterable {
    case disabled = 0
    case enabledIs = 1
    case enabledNot = 2

    /// UI cycle order when a filter chip is tapped.
    public func next() -> TriState {
        switch self {
        case .disabled: return .enabledIs
        case .enabledIs: return .enabledNot
        case .enabledNot: return .disabled
        }
    }
}

/// Apply a decoded `TriState` to a predicate. DISABLED passes everything;
/// ENABLED_IS keeps matches; ENABLED_NOT keeps non-matches.
public func applyFilter(_ filter: TriState, _ predicate: () -> Bool) -> Bool {
    switch filter {
    case .disabled: return true
    case .enabledIs: return predicate()
    case .enabledNot: return !predicate()
    }
}
