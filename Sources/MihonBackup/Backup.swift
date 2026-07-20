import Foundation
import MihonCore

/// `.tachibk` backup interop. **Platform-agnostic on purpose** — the backup
/// format is gzipped protobuf, i.e. pure bytes, so the decoder and its models
/// build and test on Windows with no Mac. This matters because backup import is
/// simultaneously the highest-risk item in the project (plan R3: the migration
/// path for every existing user, no formal spec) AND fully unit-testable in the
/// free local loop. Attack it early, here.
///
/// Wave-0 spike prerequisite (do NOT schedule the importer before this):
/// reverse-engineer the real wire format with a byte-level dumper against a real
/// `.tachibk` file. It is kotlinx.serialization's ProtoBuf dialect — field
/// numbers are scattered `@ProtoNumber` annotations with legacy gaps (100/102),
/// and `PreferenceValue` is a polymorphic sealed class with a kotlinx-specific
/// encoding that has no swift-protobuf analogue. Assume a hand-written reader
/// may be needed for the polymorphic parts.
public enum BackupFormat {
    /// Current Mihon backup file extension.
    public static let fileExtension = "tachibk"
}

/// Placeholder for the decoded backup root.
///
/// TODO(port): generate the plain messages from a validated `.proto` (derived,
/// not assumed) via swift-protobuf, and hand-roll `PreferenceValue`. Then port
/// `MangaRestorer`'s ~15 merge rules verbatim — each silently loses user data if
/// wrong (readDuration accumulation, category-by-name matching, history-by-URL).
public struct Backup: Sendable, Equatable {
    public var backupManga: [BackupManga]

    public init(backupManga: [BackupManga] = []) {
        self.backupManga = backupManga
    }
}

/// Minimal seed of a backed-up manga entry. `source` is the parity-critical
/// field — it must resolve via `SourceID` (plan R4).
public struct BackupManga: Sendable, Equatable {
    public var source: Int64
    public var url: String
    public var title: String

    public init(source: Int64, url: String, title: String) {
        self.source = source
        self.url = url
        self.title = title
    }
}
