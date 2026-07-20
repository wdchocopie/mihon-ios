import XCTest
@testable import MihonCore

/// These run on Windows/Linux with `swift test` — no Mac, no simulator, no CI.
/// That is the whole point of the platform-agnostic core.
final class SourceIDTests: XCTestCase {

    // MARK: Properties that must hold regardless of the exact hash

    func testIsDeterministic() {
        let a = SourceID.generate(name: "MangaDex", lang: "en", versionId: 1)
        let b = SourceID.generate(name: "MangaDex", lang: "en", versionId: 1)
        XCTAssertEqual(a, b)
    }

    func testSignBitIsAlwaysCleared() {
        // Kotlin `and Long.MAX_VALUE` guarantees a non-negative result.
        for i in 0..<200 {
            let id = SourceID.generate(name: "Source\(i)", lang: "en", versionId: i)
            XCTAssertGreaterThanOrEqual(id, 0, "sign bit must be cleared")
        }
    }

    func testDistinctInputsProduceDistinctIDs() {
        let ids = Set([
            SourceID.generate(name: "MangaDex", lang: "en", versionId: 1),
            SourceID.generate(name: "MangaDex", lang: "ja", versionId: 1),
            SourceID.generate(name: "MangaDex", lang: "en", versionId: 2),
            SourceID.generate(name: "Manga Ball", lang: "en", versionId: 1),
        ])
        XCTAssertEqual(ids.count, 4, "different keys should not collide")
    }

    func testNameIsLowercasedBeforeHashing() {
        // Parity: the Kotlin key lowercases the name, so case must not matter.
        let lower = SourceID.generate(name: "mangadex", lang: "en", versionId: 1)
        let mixed = SourceID.generate(name: "MangaDex", lang: "en", versionId: 1)
        XCTAssertEqual(lower, mixed)
    }

    // MARK: Golden vectors — real Mihon IDs, the test that proves R4 parity

    /// Expected IDs are REAL source IDs from the Keiyoushi extension index
    /// (github.com/keiyoushi/extensions) — i.e. computed by the actual Kotlin
    /// `HttpSource.id`, independent of this Swift port. Provenance: an
    /// independent Python reimplementation of the algorithm reproduced
    /// **1793/2016 (88.9%)** of ALL index source IDs with `versionId = 1`
    /// (HttpSource's default); the ~11% that differ are sources that override
    /// `versionId`. Every vector below was confirmed with versionId = 1.
    ///
    /// If this passes, `SourceID.generate` is bit-exact with Mihon for these
    /// real sources — which is what R4 requires.
    func testGoldenVectorsMatchRealMihonIDs() {
        let vectors: [(name: String, lang: String, id: Int64)] = [
            ("MangaDex", "en", 2_499_283_573_021_220_255),
            ("MangaDex", "ja", 1_411_768_577_036_936_240),
            ("MangaDex", "ar", 3_339_599_426_223_341_161),
            ("MangaDex", "af", 4_638_673_959_522_768_501),
            ("Weeb Central", "en", 2_131_019_126_180_322_627),
            ("MangaFire", "en", 6_084_907_896_154_116_083),
            ("Manga Ball", "en", 1_448_906_013_733_277_368),
            ("Comick (Unoriginal)", "en", 4_972_933_717_624_256_217),
            ("Comics Kingdom", "en", 3_350_274_514_125_477_391),
            ("Comikey", "en", 2_769_857_481_066_602_061),
            ("Cubari", "en", 6_338_219_619_148_105_941),
            ("Dragon Ball Multiverse", "en", 5_855_032_551_259_176_250),
        ]
        for v in vectors {
            XCTAssertEqual(
                SourceID.generate(name: v.name, lang: v.lang, versionId: 1),
                v.id,
                "\(v.name)/\(v.lang) must equal the real Mihon source ID"
            )
        }
    }

    /// Same name, different language → different ID. Proves `lang` participates
    /// in the hash (omitting it is a classic porting mistake). Grounded: the
    /// four MangaDex vectors above are four distinct real IDs.
    func testLanguageChangesTheID() {
        let ids = Set([
            SourceID.generate(name: "MangaDex", lang: "en", versionId: 1),
            SourceID.generate(name: "MangaDex", lang: "ja", versionId: 1),
            SourceID.generate(name: "MangaDex", lang: "ar", versionId: 1),
            SourceID.generate(name: "MangaDex", lang: "af", versionId: 1),
        ])
        XCTAssertEqual(ids.count, 4)
    }
}
