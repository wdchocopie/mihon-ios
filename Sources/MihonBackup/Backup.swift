import Foundation
import MihonCore

/// `.tachibk` backup interop. **Platform-agnostic on purpose** — the backup
/// format is gzipped protobuf, i.e. pure bytes, so the decoder and its models
/// build and test on Windows with no Mac. This is simultaneously the project's
/// highest-risk item (plan R3: the migration path for every existing user, no
/// formal spec) AND fully unit-testable in the free local loop.
///
/// The models live in `Model/BackupModels.swift`; the wire codec in
/// `Protobuf/ProtobufWire.swift`; the top-level entry in `BackupDecoder.swift`.
/// Schema + findings: docs/specs/2026-07-20-tachibk-decoder-design.md.
public enum BackupFormat {
    /// Current Mihon backup file extension.
    public static let fileExtension = "tachibk"
}
