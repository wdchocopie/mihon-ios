import Foundation

// A minimal, dependency-free protobuf wire-format reader + writer, matching the
// kotlinx-serialization ProtoBuf conventions Mihon uses (see the decoder design
// spec). Deliberately NOT swift-protobuf: we need non-packed repeated scalars,
// Kotlin default-omission, and (later) the polymorphic PreferenceValue wrapper,
// none of which swift-protobuf's generated proto3 code expresses. Staying
// hand-rolled also keeps this platform-agnostic (tests run on Windows).

public enum ProtobufWireType: Int, Sendable {
    case varint = 0
    case fixed64 = 1
    case lengthDelimited = 2
    case fixed32 = 5
}

public enum ProtobufError: Error, Equatable, Sendable {
    case truncated
    case malformedVarint
    case unknownWireType(Int)
    case unexpectedWireType(field: Int, got: Int)
}

// MARK: - Reader

/// Reads protobuf fields off a byte buffer. Value semantics: `offset` advances
/// as you read. Sub-messages are decoded by handing `readBytes()` to another
/// reader.
public struct ProtobufWireReader: Sendable {
    public let bytes: [UInt8]
    public private(set) var offset: Int

    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
        self.offset = 0
    }

    public var isAtEnd: Bool { offset >= bytes.count }

    /// Next field header, or nil at end of buffer.
    public mutating func readTag() throws -> (field: Int, wire: ProtobufWireType)? {
        if isAtEnd { return nil }
        let key = try readVarint()
        let field = Int(key >> 3)
        let raw = Int(key & 0x7)
        guard let wire = ProtobufWireType(rawValue: raw) else {
            throw ProtobufError.unknownWireType(raw)
        }
        return (field, wire)
    }

    public mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard offset < bytes.count else { throw ProtobufError.truncated }
            let b = bytes[offset]
            offset += 1
            result |= UInt64(b & 0x7F) << shift
            if b & 0x80 == 0 { break }
            shift += 7
            if shift >= 64 { throw ProtobufError.malformedVarint }
        }
        return result
    }

    /// Kotlin Long/Int use DEFAULT (two's-complement) varint, not zigzag.
    public mutating func readInt64() throws -> Int64 { Int64(bitPattern: try readVarint()) }
    public mutating func readInt() throws -> Int { Int(truncatingIfNeeded: try readInt64()) }
    public mutating func readBool() throws -> Bool { try readVarint() != 0 }

    public mutating func readFixed32() throws -> UInt32 {
        guard offset + 4 <= bytes.count else { throw ProtobufError.truncated }
        var v: UInt32 = 0
        for i in 0..<4 { v |= UInt32(bytes[offset + i]) << (8 * i) } // little-endian
        offset += 4
        return v
    }

    public mutating func readFixed64() throws -> UInt64 {
        guard offset + 8 <= bytes.count else { throw ProtobufError.truncated }
        var v: UInt64 = 0
        for i in 0..<8 { v |= UInt64(bytes[offset + i]) << (8 * i) }
        offset += 8
        return v
    }

    public mutating func readFloat() throws -> Float { Float(bitPattern: try readFixed32()) }

    public mutating func readBytes() throws -> [UInt8] {
        let len = Int(try readVarint())
        guard len >= 0, offset + len <= bytes.count else { throw ProtobufError.truncated }
        let slice = Array(bytes[offset ..< offset + len])
        offset += len
        return slice
    }

    public mutating func readString() throws -> String {
        String(decoding: try readBytes(), as: UTF8.self)
    }

    /// Skip an unknown field so forward-compat data (and deferred fields like
    /// preferences) don't break decoding.
    public mutating func skip(_ wire: ProtobufWireType) throws {
        switch wire {
        case .varint: _ = try readVarint()
        case .fixed64: _ = try readFixed64()
        case .fixed32: _ = try readFixed32()
        case .lengthDelimited: _ = try readBytes()
        }
    }
}

// MARK: - Writer

/// Emits wire bytes. Used by the round-trip tests now; the basis for a
/// Mihon-compatible backup EXPORT later (which additionally must omit
/// default-valued fields to match kotlinx byte-for-byte — deferred).
public struct ProtobufWireWriter: Sendable {
    public private(set) var bytes: [UInt8] = []
    public init() {}

    public mutating func writeVarint(_ value: UInt64) {
        var v = value
        repeat {
            var b = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { b |= 0x80 }
            bytes.append(b)
        } while v != 0
    }

    private mutating func writeTag(_ field: Int, _ wire: ProtobufWireType) {
        writeVarint((UInt64(field) << 3) | UInt64(wire.rawValue))
    }

    public mutating func int64(_ field: Int, _ value: Int64) {
        writeTag(field, .varint); writeVarint(UInt64(bitPattern: value))
    }
    public mutating func int(_ field: Int, _ value: Int) { int64(field, Int64(value)) }
    public mutating func bool(_ field: Int, _ value: Bool) {
        writeTag(field, .varint); writeVarint(value ? 1 : 0)
    }
    public mutating func float(_ field: Int, _ value: Float) {
        writeTag(field, .fixed32)
        let bits = value.bitPattern
        for i in 0..<4 { bytes.append(UInt8((bits >> (8 * i)) & 0xFF)) }
    }
    public mutating func bytesField(_ field: Int, _ value: [UInt8]) {
        writeTag(field, .lengthDelimited); writeVarint(UInt64(value.count)); bytes += value
    }
    public mutating func string(_ field: Int, _ value: String) {
        bytesField(field, Array(value.utf8))
    }
    /// Nested message: length-prefixed sub-message bytes.
    public mutating func message(_ field: Int, _ sub: [UInt8]) {
        bytesField(field, sub)
    }
}
