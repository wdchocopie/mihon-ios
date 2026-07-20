import Foundation
import Crypto

/// Computes a source's stable numeric ID.
///
/// **This is a hard correctness requirement (plan R4).** The ID it produces is
/// stored in the DB `mangas.source` column and embedded in every `.tachibk`
/// backup. If the iOS runtime computes a different ID than Mihon did, every
/// imported library entry orphans — the import "succeeds" but resolves to no
/// source. The port MUST be bit-exact against Mihon for all real source IDs.
///
/// Kotlin original (`source-api/.../source/online/HttpSource.kt:98-102`):
/// ```
/// val key = "${name.lowercase()}/$lang/$versionId"
/// val bytes = MessageDigest.getInstance("MD5").digest(key.toByteArray())
/// (0..7).map { bytes[it].toLong() and 0xff shl 8 * (7 - it) }
///     .reduce(Long::or) and Long.MAX_VALUE
/// ```
/// i.e. MD5 of the key, first 8 bytes read big-endian into a 64-bit integer,
/// then the sign bit cleared.
public enum SourceID {
    public static func generate(name: String, lang: String, versionId: Int) -> Int64 {
        // NOTE(parity): Kotlin `String.lowercase()` is locale-independent.
        // Swift's `lowercased()` is Unicode-aware; for the ASCII source names
        // in practice these agree, but the golden-vector test below is what
        // actually pins parity — do not assume, verify against real IDs.
        let key = "\(name.lowercased())/\(lang)/\(versionId)"
        let digest = Insecure.MD5.hash(data: Data(key.utf8))
        let bytes = Array(digest) // 16 bytes

        var value: UInt64 = 0
        for i in 0..<8 {
            value |= UInt64(bytes[i]) << (8 * (7 - i))
        }
        // Clear the sign bit — equivalent to Kotlin `and Long.MAX_VALUE`.
        value &= 0x7FFF_FFFF_FFFF_FFFF
        return Int64(bitPattern: value)
    }
}
