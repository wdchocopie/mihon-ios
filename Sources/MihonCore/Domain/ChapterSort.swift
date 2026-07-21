import Foundation

/// Chapter sorting, ported from `domain/.../chapter/service/ChapterSort.kt`.
///
/// Produces a 3-way comparator `(Chapter, Chapter) -> Int` selected by the
/// manga's `sorting` mode and direction. Behaviour is bit-exact with Mihon:
///
/// - **SOURCE is INVERTED** relative to the other three modes: with
///   `sortDescending == true` it compares `c1.sourceOrder` vs `c2.sourceOrder`
///   (ascending sign), whereas NUMBER / UPLOAD_DATE / ALPHABET compare `c2` vs
///   `c1` when descending. This mirrors the Kotlin source literally — do NOT
///   collapse it into a single generic flip.
/// - **NUMBER** compares `Double` via a NaN-safe 3-way compare that mirrors
///   Kotlin/Java `Double.compareTo` (`Double.compare`): a total order where NaN
///   sorts greater than everything (including +∞) and `-0.0 < 0.0`. It never
///   traps, so Swift's sort can't crash on inconsistent ordering.
/// - **UPLOAD_DATE** compares `dateUpload` (`Int64`).
/// - **ALPHABET** compares `name` via `localizedStandardCompare` (a v1
///   approximation of Mihon's locale `Collator`).
/// - An unrecognised sort mode is a programmer error → `fatalError`.

/// NaN-safe 3-way compare of two `Double`s, faithful to Kotlin `Double.compareTo`
/// (JVM `Double.compare`): NaN is treated as greater than every other value and
/// equal to itself; `-0.0` sorts below `0.0`. Never traps.
@inline(__always)
private func kotlinDoubleCompare(_ d1: Double, _ d2: Double) -> Int {
    if d1 < d2 { return -1 }
    if d1 > d2 { return 1 }
    // Equal under < / >, OR one/both are NaN. Fall back to canonicalised bits,
    // matching Java's `doubleToLongBits` (all NaNs collapse to one value).
    let canonicalNaN: UInt64 = 0x7ff8_0000_0000_0000
    let b1 = Int64(bitPattern: d1.isNaN ? canonicalNaN : d1.bitPattern)
    let b2 = Int64(bitPattern: d2.isNaN ? canonicalNaN : d2.bitPattern)
    if b1 == b2 { return 0 }
    return b1 < b2 ? -1 : 1
}

/// 3-way compare of two `Int64`s → -1 / 0 / 1.
@inline(__always)
private func int64Compare(_ a: Int64, _ b: Int64) -> Int {
    a < b ? -1 : (a > b ? 1 : 0)
}

/// Build the chapter comparator for `manga`. `sortDescending` defaults to the
/// manga's persisted direction bit.
public func getChapterSort(
    _ manga: Manga,
    sortDescending: Bool? = nil
) -> (Chapter, Chapter) -> Int {
    let descending = sortDescending ?? manga.sortDescending()

    switch manga.sorting {
    case Manga.chapterSortingSource:
        // INVERTED vs the other three modes.
        if descending {
            return { c1, c2 in int64Compare(c1.sourceOrder, c2.sourceOrder) }
        } else {
            return { c1, c2 in int64Compare(c2.sourceOrder, c1.sourceOrder) }
        }

    case Manga.chapterSortingNumber:
        if descending {
            return { c1, c2 in kotlinDoubleCompare(c2.chapterNumber, c1.chapterNumber) }
        } else {
            return { c1, c2 in kotlinDoubleCompare(c1.chapterNumber, c2.chapterNumber) }
        }

    case Manga.chapterSortingUploadDate:
        if descending {
            return { c1, c2 in int64Compare(c2.dateUpload, c1.dateUpload) }
        } else {
            return { c1, c2 in int64Compare(c1.dateUpload, c2.dateUpload) }
        }

    case Manga.chapterSortingAlphabet:
        if descending {
            return { c1, c2 in collatorCompare(c2.name, c1.name) }
        } else {
            return { c1, c2 in collatorCompare(c1.name, c2.name) }
        }

    default:
        fatalError("Invalid chapter sorting method: \(manga.sorting)")
    }
}

/// PRIMARY-strength collation matching Mihon's `compareToWithCollator`
/// (`Collator(strength = PRIMARY)`): case- and diacritic-insensitive, then a
/// **lexical** (codepoint) compare — deliberately NOT numeric. This differs from
/// `localizedStandardCompare`, which does Finder-style numeric runs and would
/// invert e.g. "Chapter 2" vs "Chapter 10". Folding + `<` is also deterministic
/// across platforms (avoids Linux-vs-Apple ICU collation drift).
private func collatorCompare(_ a: String, _ b: String) -> Int {
    let fa = a.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    let fb = b.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    if fa == fb { return 0 }
    return fa < fb ? -1 : 1
}

@inline(__always)
private func comparisonToInt(_ result: ComparisonResult) -> Int {
    switch result {
    case .orderedAscending: return -1
    case .orderedSame: return 0
    case .orderedDescending: return 1
    }
}

/// Sort `chapters` for `manga` with a STABLE order. Swift's `sorted(by:)` is not
/// guaranteed stable, so equal keys are broken by ORIGINAL INDEX ASCENDING —
/// always, independent of the sort direction (direction lives only in the
/// primary comparator). This reproduces the ordering a stable Kotlin sort yields.
public func sortedChapters(
    _ chapters: [Chapter],
    for manga: Manga,
    sortDescending: Bool? = nil
) -> [Chapter] {
    let comparator = getChapterSort(manga, sortDescending: sortDescending)
    return chapters.enumerated()
        .sorted { lhs, rhs in
            let primary = comparator(lhs.element, rhs.element)
            if primary != 0 { return primary < 0 }
            return lhs.offset < rhs.offset   // stable tiebreak: input order
        }
        .map { $0.element }
}
