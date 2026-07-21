import Foundation
import MihonCore

/// Bit-exact ports of Mihon's SQLDelight column adapters (`DatabaseAdapter.kt`),
/// which convert between raw DB column values and typed Swift values.
///
/// These are **GRDB-agnostic on purpose** — pure value conversions with no SQLite
/// dependency, so they build and test on Windows. The GRDB execution tier (a
/// CI-gated follow-up; GRDB cannot build on Windows) wires these into row access.
///
/// The genre separator is **backup-boundary-critical**: it must be exactly ", "
/// so that a `genre` TEXT column round-trips identically to Mihon and to
/// `.tachibk` exports.

/// `List<String>` ⟷ TEXT, joined by ", ".
public enum StringListColumnAdapter {
    public static let separator = ", "

    public static func decode(_ dbValue: String) -> [String] {
        dbValue.isEmpty ? [] : dbValue.components(separatedBy: separator)
    }

    public static func encode(_ value: [String]) -> String {
        value.joined(separator: separator)
    }
}

/// `UpdateStrategy` ⟷ INTEGER (enum ordinal). Unknown ordinals decode to
/// `.alwaysUpdate`, mirroring Kotlin's `getOrElse { ALWAYS_UPDATE }`.
public enum UpdateStrategyColumnAdapter {
    public static func decode(_ dbValue: Int64) -> UpdateStrategy {
        UpdateStrategy(rawValue: Int(truncatingIfNeeded: dbValue)) ?? .alwaysUpdate
    }

    public static func encode(_ value: UpdateStrategy) -> Int64 {
        Int64(value.rawValue)
    }
}

/// `Bool` ⟷ INTEGER (0/1). SQLDelight stores `AS Boolean` columns this way.
public enum BooleanColumnAdapter {
    public static func decode(_ dbValue: Int64) -> Bool { dbValue != 0 }
    public static func encode(_ value: Bool) -> Int64 { value ? 1 : 0 }
}

/// `Date` ⟷ INTEGER (epoch millis). Our domain entities already store dates as
/// `Int64` epoch millis, so this is an identity passthrough — provided for
/// parity with `DateColumnAdapter` and for the `last_read` INTEGER AS Date column.
public enum DateColumnAdapter {
    public static func decode(_ dbValue: Int64) -> Int64 { dbValue }
    public static func encode(_ value: Int64) -> Int64 { value }
}

/// `JSONValue` (memo) ⟷ BLOB (UTF-8 JSON bytes). Mihon stores
/// `value.toString().encodeToByteArray()`; we emit compact, key-sorted JSON so
/// the stored bytes are deterministic and round-trip losslessly.
///
/// Note: byte-for-byte equality with kotlinx's `JsonObject.toString()` is NOT
/// guaranteed (key ordering / number formatting differ). That only matters for
/// `.tachibk` EXPORT parity, which is deferred; within the iOS DB these bytes
/// only need to round-trip consistently, which they do.
public enum MemoColumnAdapter {
    public static func decode(_ dbValue: [UInt8]) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(dbValue))
    }

    public static func encode(_ value: JSONValue) throws -> [UInt8] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return Array(try encoder.encode(value))
    }

    /// The default empty-memo bytes (`{}`).
    public static let emptyBytes: [UInt8] = Array("{}".utf8)
}
