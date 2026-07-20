import Foundation

/// Top-level `.tachibk` decode entry, mirroring Mihon's `BackupDecoder.kt`.
///
/// Mihon peeks the first two bytes to route the payload:
///   0x1f8b            → gzip; gunzip then protobuf-decode
///   0x7b7d/0x7b22/0x7b0a (`{}`,`{"`,`{\n`) → legacy JSON backup → reject
///   else              → raw (un-gzipped) protobuf
public enum BackupDecoder {
    public enum DecodeError: Error, Equatable, Sendable {
        case legacyJSONBackup
        /// Payload is gzipped; inflate is not yet wired in (spike defers it).
        case gzipInflateNotImplemented
        case emptyData
    }

    /// Detected container of a `.tachibk` byte blob.
    public enum Container: Equatable, Sendable {
        case gzip
        case rawProtobuf
        case legacyJSON
    }

    /// Classify by the leading magic bytes — the exact routing Mihon does.
    public static func detectContainer(_ data: [UInt8]) throws -> Container {
        guard data.count >= 2 else { throw DecodeError.emptyData }
        let magic = (Int(data[0]) << 8) | Int(data[1])
        switch magic {
        case 0x1f8b: return .gzip
        case 0x7b7d, 0x7b22, 0x7b0a: return .legacyJSON
        default: return .rawProtobuf
        }
    }

    /// Decode an already-decompressed (raw) protobuf backup payload.
    public static func decodeRawProtobuf(_ data: [UInt8]) throws -> Backup {
        try Backup.decode(data)
    }

    /// Decode a full `.tachibk` blob. Handles container detection; gzip inflate
    /// is deferred (the outer wrapper is a known, separable step — see spec).
    /// For gzipped input, gunzip first and call `decodeRawProtobuf`.
    public static func decode(_ data: [UInt8]) throws -> Backup {
        switch try detectContainer(data) {
        case .legacyJSON: throw DecodeError.legacyJSONBackup
        case .gzip: throw DecodeError.gzipInflateNotImplemented
        case .rawProtobuf: return try decodeRawProtobuf(data)
        }
    }
}
