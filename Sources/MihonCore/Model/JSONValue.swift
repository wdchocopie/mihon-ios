import Foundation

/// A concrete, value-type JSON tree. Ports Mihon's `memo: JsonObject` fields
/// (Manga/Chapter/SManga) into something Equatable/Hashable/Codable/Sendable —
/// `[String: Any]` conforms to none of those, and `ShouldUpdateDbChapter`
/// compares `memo != memo`, so a concrete type is required (plan review).
public enum JSONValue: Sendable, Hashable, Codable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    /// Integer JSON numbers are kept as `Int64` (not collapsed to `Double`) so
    /// large IDs like 2^53+1 round-trip losslessly and `1` ≠ `1.0` — matching
    /// kotlinx `JsonPrimitive`'s content-based equality, which `ShouldUpdateDbChapter`
    /// relies on. Numbers outside `Double` range (e.g. 1e400) remain a known
    /// micro-divergence (astronomically rare in `memo`; see decode below).
    case int(Int64)
    case number(Double)
    case bool(Bool)
    case null

    /// The default empty `memo` value (`{}`).
    public static let empty: JSONValue = .object([:])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int64.self) {
            self = .int(i)   // integers first — preserves values beyond Double's 2^53
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unrecognized JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let o): try c.encode(o)
        case .array(let a): try c.encode(a)
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        }
    }
}
