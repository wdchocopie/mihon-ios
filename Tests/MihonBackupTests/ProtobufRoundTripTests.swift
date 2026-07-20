import XCTest
@testable import MihonBackup

/// Spike verification: prove Swift can decode the kotlinx-protobuf `.tachibk`
/// wire format, with the kotlinx conventions and Kotlin defaults reproduced.
/// Runs on Windows/Linux with `swift test` — no Mac.
///
/// NOTE: this proves LOGICAL round-trip (our writer ↔ our reader) and the
/// derived-schema behaviors. Byte-exact validation against a REAL Mihon
/// `.tachibk` is the pending step (needs a user-exported file); until then R3
/// is "characterized", not "closed".
final class ProtobufRoundTripTests: XCTestCase {

    // MARK: Wire primitives

    func testInt64VarintRoundTripIncludingNegatives() throws {
        for v: Int64 in [0, 1, -1, 127, 128, 9_876_543_210, -9_876_543_210, .max, .min] {
            var w = ProtobufWireWriter()
            w.int64(5, v)
            var r = ProtobufWireReader(w.bytes)
            let tag = try r.readTag()
            XCTAssertEqual(tag?.field, 5)
            XCTAssertEqual(tag?.wire, .varint)
            XCTAssertEqual(try r.readInt64(), v, "varint two's-complement round-trip for \(v)")
        }
    }

    func testFloatRoundTrip() throws {
        for v: Float in [0, 1.5, -3.25, 8.5, 123456.0] {
            var w = ProtobufWireWriter()
            w.float(9, v)
            var r = ProtobufWireReader(w.bytes)
            _ = try r.readTag()
            XCTAssertEqual(try r.readFloat(), v)
        }
    }

    // MARK: The R3 data-loss guard

    func testAbsentFavoriteFieldDefaultsToTrue() throws {
        // A manga wire with NO field 100 must decode favorite = TRUE. A decoder
        // that defaulted bool to false would silently un-favorite the library.
        var w = ProtobufWireWriter()
        w.int64(1, 123)          // source
        w.string(2, "/manga/x")  // url
        w.string(3, "Title")     // title
        // deliberately omit field 100 (favorite)
        let m = try BackupManga.decode(w.bytes)
        XCTAssertTrue(m.favorite, "absent favorite must default to true (Kotlin default)")
        XCTAssertEqual(m.title, "Title")
        XCTAssertEqual(m.source, 123)
    }

    func testExplicitFavoriteFalseIsPreserved() throws {
        var w = ProtobufWireWriter()
        w.int64(1, 1); w.string(2, "/m")
        w.bool(100, false)
        let m = try BackupManga.decode(w.bytes)
        XCTAssertFalse(m.favorite)
    }

    // MARK: Forward-compat

    func testUnknownFieldsAreSkipped() throws {
        // Deferred fields (preferences) and future additions must not break decode.
        var w = ProtobufWireWriter()
        w.int64(1, 42); w.string(2, "/u")
        w.string(500, "future string field")
        w.int64(999, 12_345)
        w.float(777, 3.14)
        let m = try BackupManga.decode(w.bytes)
        XCTAssertEqual(m.source, 42)
        XCTAssertEqual(m.url, "/u")
    }

    // MARK: Full logical round-trip

    func testFullBackupRoundTrip() throws {
        let backup = Backup(
            backupManga: [
                BackupManga(
                    source: 9_876_543_210,
                    url: "/manga/1",
                    title: "Test Manga",
                    author: "Author",
                    genre: ["Action", "Comedy"],
                    status: 2,
                    dateAdded: 1_600_000_000_000,
                    chapters: [
                        BackupChapter(url: "/c/1", name: "Ch 1", read: true,
                                      lastPageRead: 12, chapterNumber: 1.5),
                        BackupChapter(url: "/c/2", name: "Ch 2"),
                    ],
                    categories: [1, 2],
                    tracking: [
                        BackupTracking(syncId: 1, libraryId: 0, title: "MAL",
                                       score: 8.5, mediaId: 42),
                    ],
                    favorite: true,
                    chapterFlags: 7,
                    history: [
                        BackupHistory(url: "/c/1", lastRead: 1_700_000_000_000,
                                      readDuration: 5000),
                    ],
                    version: 3,
                    notes: "some notes"
                ),
            ],
            backupCategories: [BackupCategory(name: "Reading", order: 0, id: 1, flags: 4)],
            backupSources: [BackupSource(name: "MangaDex", sourceId: 9_876_543_210)]
        )

        let decoded = try Backup.decode(backup.encode())
        XCTAssertEqual(decoded, backup)
    }

    // MARK: MangaRestorer parity rules (pure logic)

    func testTrackingRemoteIdUsesLegacyMediaIdIntWhenNonZero() {
        XCTAssertEqual(BackupTracking(syncId: 1, libraryId: 0, mediaIdInt: 5, mediaId: 99).remoteId, 5)
        XCTAssertEqual(BackupTracking(syncId: 1, libraryId: 0, mediaIdInt: 0, mediaId: 99).remoteId, 99)
    }

    func testEffectiveViewerFlagsFallsBackToViewer() {
        XCTAssertEqual(BackupManga(source: 0, url: "", viewer: 3, viewerFlags: nil).effectiveViewerFlags, 3)
        XCTAssertEqual(BackupManga(source: 0, url: "", viewer: 3, viewerFlags: 7).effectiveViewerFlags, 7)
    }

    // MARK: Container detection (BackupDecoder.kt parity)

    func testContainerDetection() throws {
        XCTAssertEqual(try BackupDecoder.detectContainer([0x1f, 0x8b, 0x08, 0x00]), .gzip)
        XCTAssertEqual(try BackupDecoder.detectContainer(Array("{}".utf8)), .legacyJSON)
        XCTAssertEqual(try BackupDecoder.detectContainer(Array("{\"".utf8)), .legacyJSON)
        XCTAssertEqual(try BackupDecoder.detectContainer([0x0a, 0x05]), .rawProtobuf)
    }

    func testDecodeRoutesLegacyJSONAndGzip() {
        XCTAssertThrowsError(try BackupDecoder.decode(Array("{}".utf8))) { error in
            XCTAssertEqual(error as? BackupDecoder.DecodeError, .legacyJSONBackup)
        }
        XCTAssertThrowsError(try BackupDecoder.decode([0x1f, 0x8b, 0x00])) { error in
            XCTAssertEqual(error as? BackupDecoder.DecodeError, .gzipInflateNotImplemented)
        }
    }

    func testDecodeRawProtobufBackup() throws {
        let backup = Backup(backupManga: [BackupManga(source: 7, url: "/m", title: "T")])
        // encode() yields raw protobuf (field 1 tag 0x0a → not a magic prefix).
        let decoded = try BackupDecoder.decode(backup.encode())
        XCTAssertEqual(decoded.backupManga.count, 1)
        XCTAssertEqual(decoded.backupManga.first?.title, "T")
    }
}
