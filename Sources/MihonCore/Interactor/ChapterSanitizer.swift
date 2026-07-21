import Foundation

/// Cleans a source chapter name, ported from `ChapterSanitizer.kt`:
/// `trim()` → `removePrefix(mangaTitle)` → trim a specific whitespace+separator set.
public enum ChapterSanitizer {
    public static func sanitize(_ name: String, title: String) -> String {
        var s = trim(name) { $0.isWhitespace }
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
    /// from a source chapter. Blank scanlator → nil, else trimmed.
    func copyFrom(sChapter: SChapter) -> Chapter {
        var c = self
        c.name = sChapter.name
        c.url = sChapter.url
        c.dateUpload = sChapter.dateUpload
        c.chapterNumber = Double(sChapter.chapterNumber)
        if let s = sChapter.scanlator, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            c.scanlator = s.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            c.scanlator = nil
        }
        c.memo = sChapter.memo
        return c
    }
}
