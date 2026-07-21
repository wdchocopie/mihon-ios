import Foundation

/// Cleans a source chapter name, ported from `ChapterSanitizer.kt`:
/// `trim()` → `removePrefix(mangaTitle)` → trim a specific whitespace+separator set.
public enum ChapterSanitizer {
    public static func sanitize(_ name: String, title: String) -> String {
        // Step 1 uses Kotlin's whitespace definition (see `isKotlinWhitespace`),
        // NOT Swift's Unicode White_Space — they diverge on U+0085 and U+001C–1F,
        // and step 1 gates the title-prefix removal.
        var s = trim(name) { isKotlinWhitespaceCharacter($0) }
        if !title.isEmpty, s.hasPrefix(title) {
            s = String(s.dropFirst(title.count))
        }
        s = trim(s) { trimChars.contains($0) }
        return s
    }

    private static func trim(_ s: String, where predicate: (Character) -> Bool) -> String {
        var slice = Substring(s)
        while let first = slice.first, predicate(first) { slice = slice.dropFirst() }
        while let last = slice.last, predicate(last) { slice = slice.dropLast() }
        return String(slice)
    }

    /// Verbatim from `CHAPTER_TRIM_CHARS`: whitespace variants + `- _ , :`.
    private static let trimChars: Set<Character> = [
        " ", "\u{0009}", "\u{000A}", "\u{000B}", "\u{000C}", "\u{000D}", "\u{0020}",
        "\u{0085}", "\u{00A0}", "\u{1680}", "\u{2000}", "\u{2001}", "\u{2002}",
        "\u{2003}", "\u{2004}", "\u{2005}", "\u{2006}", "\u{2007}", "\u{2008}",
        "\u{2009}", "\u{200A}", "\u{2028}", "\u{2029}", "\u{202F}", "\u{205F}",
        "\u{3000}", "-", "_", ",", ":",
    ]
}

public extension Chapter {
    /// Ports `Chapter.copyFromSChapter`: name/url/dateUpload/chapterNumber/scanlator/memo
    /// from a source chapter. Blank scanlator → nil, else trimmed (Kotlin
    /// `scanlator?.ifBlank { null }?.trim()`, using Kotlin's whitespace set).
    func copyFrom(sChapter: SChapter) -> Chapter {
        var c = self
        c.name = sChapter.name
        c.url = sChapter.url
        c.dateUpload = sChapter.dateUpload
        c.chapterNumber = Double(sChapter.chapterNumber)
        c.scanlator = normalizeScanlator(sChapter.scanlator)
        c.memo = sChapter.memo
        return c
    }
}

/// Kotlin `scanlator?.ifBlank { null }?.trim()` — nil if nil or all-whitespace,
/// otherwise trimmed, using Kotlin's whitespace definition.
public func normalizeScanlator(_ scanlator: String?) -> String? {
    guard let s = scanlator else { return nil }
    let trimmed = trimKotlinWhitespace(s)
    return trimmed.isEmpty ? nil : trimmed
}

func trimKotlinWhitespace(_ s: String) -> String {
    var slice = Substring(s)
    while let first = slice.first, isKotlinWhitespaceCharacter(first) { slice = slice.dropFirst() }
    while let last = slice.last, isKotlinWhitespaceCharacter(last) { slice = slice.dropLast() }
    return String(slice)
}

/// A `Character` that is a single scalar matching `isKotlinWhitespace`. All
/// whitespace is single-scalar BMP, so this maps 1:1 onto Kotlin's per-`Char` trim.
func isKotlinWhitespaceCharacter(_ c: Character) -> Bool {
    c.unicodeScalars.count == 1 && isKotlinWhitespace(c.unicodeScalars.first!)
}

/// Matches Kotlin's `Char.isWhitespace()` (= Java `isWhitespace() || isSpaceChar()`),
/// which differs from Swift's Unicode `White_Space`: Kotlin **excludes** U+0085
/// (NEL) and **includes** U+001C–U+001F (FS/GS/RS/US). Everything else — the
/// space separators (incl. no-break) and U+0009–000D/2028/2029 — agrees.
func isKotlinWhitespace(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x1C...0x1F: return true
    case 0x85: return false
    default: return scalar.properties.isWhitespace
    }
}
