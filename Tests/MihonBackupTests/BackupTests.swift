import XCTest
@testable import MihonBackup
import MihonCore

final class BackupTests: XCTestCase {

    func testFileExtensionIsTachibk() {
        XCTAssertEqual(BackupFormat.fileExtension, "tachibk")
    }

    func testBackupMangaCarriesSourceID() {
        // The `source` field must survive as the parity-critical Int64 (R4).
        let entry = BackupManga(source: 2_499_283_573_021_220_255, url: "/m/1", title: "X")
        XCTAssertEqual(entry.source, 2_499_283_573_021_220_255)
    }

    // TODO(R3): the real tests here decode a corpus of real `.tachibk` files and
    // assert exact round-trips, including the readDuration-accumulation and
    // category-by-name edge cases. Blocked on the Wave-0 wire-format spike.
}
