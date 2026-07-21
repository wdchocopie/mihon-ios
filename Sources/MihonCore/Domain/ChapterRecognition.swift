import Foundation

/// Recovers a numeric chapter number from a chapter's title, ported verbatim from
/// `domain/.../chapter/service/ChapterRecognition.kt`.
///
/// Engine note: this MUST use `NSRegularExpression` (ICU), NOT Swift's native
/// `Regex`. The `basic` pattern relies on a fixed-width lookbehind `(?<=ch\.)`
/// that Swift's own regex engine rejects. The four patterns are compiled once as
/// `static let` from raw string literals so the semantics cross the DB boundary
/// unchanged.
public enum ChapterRecognition {

    // MARK: Patterns (compiled once — verbatim from the Kotlin source)

    /// `([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?` — group 1 integer, group 2 decimal
    /// (leading dot), group 3 alpha postfix (optional leading dot).
    private static let numberPattern = #"([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?"#

    /// Number, anywhere.
    private static let number = try! NSRegularExpression(pattern: numberPattern)

    /// Number immediately after a `ch.` prefix (fixed-width lookbehind + spaces).
    private static let basic = try! NSRegularExpression(pattern: #"(?<=ch\.) *"# + numberPattern)

    /// Volume / version / season tags glued to a number, stripped when a title
    /// yields more than one candidate number. NOTE: `volume` MUST stay in the
    /// alternation — `vol` alone does not match `volume64`.
    private static let unwanted = try! NSRegularExpression(
        // Java `\b`/`\w` are ASCII-only; ICU's are Unicode-aware. Input is already
        // lowercased, so reproduce Java's ASCII left word-boundary with a
        // negative lookbehind on ASCII word chars — else a non-ASCII prefix
        // (e.g. "봄vol1") would suppress the boundary and mis-parse the number.
        pattern: #"(?<![a-z0-9_])(?:v|ver|vol|version|volume|season|s)[^a-z]?[0-9]+"#
    )

    /// Whitespace directly before an `extra`/`special`/`omake` tag (removed so the
    /// tag binds to the preceding number).
    private static let unwantedWhiteSpace = try! NSRegularExpression(
        // Java `\s` is ASCII [ \t\n\x0B\f\r]; ICU `\s` also matches Unicode spaces
        // (e.g. NBSP). Pin the ASCII set so a non-breaking space isn't stripped.
        pattern: #"[ \t\n\x0B\f\r](?=extra|special|omake)"#
    )

    // MARK: Public API

    /// Returns the recognized chapter number, or `-1.0` when nothing parseable is
    /// found. A caller-supplied `chapterNumber` that is already known
    /// (`== -2.0` sentinel, or `> -1.0`) is trusted and returned as-is.
    public static func parseChapterNumber(
        mangaTitle: String,
        chapterName: String,
        chapterNumber: Double? = nil
    ) -> Double {
        // If chapter number is known, return it directly.
        if let chapterNumber, chapterNumber == -2.0 || chapterNumber > -1.0 {
            return chapterNumber
        }

        var cleanChapterName = chapterName.lowercased()
        cleanChapterName = cleanChapterName.replacingOccurrences(of: mangaTitle.lowercased(), with: "")
        cleanChapterName = cleanChapterName.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanChapterName = cleanChapterName.replacingOccurrences(of: ",", with: ".")
        cleanChapterName = cleanChapterName.replacingOccurrences(of: "-", with: ".")
        cleanChapterName = replaceAll(unwantedWhiteSpace, in: cleanChapterName, with: "")

        // Materialize matches once (Kotlin's Sequence would lazily re-scan).
        let numberMatches = allMatches(number, in: cleanChapterName)

        if numberMatches.isEmpty {
            return chapterNumber ?? -1.0
        }

        if numberMatches.count > 1 {
            let name = replaceAll(unwanted, in: cleanChapterName, with: "")
            if let match = firstMatch(basic, in: name) {
                return chapterNumberFromMatch(match, in: name)
            }
            if let match = firstMatch(number, in: name) {
                return chapterNumberFromMatch(match, in: name)
            }
        }

        // Fall through: first match of the ORIGINAL cleaned name.
        return chapterNumberFromMatch(numberMatches[0], in: cleanChapterName)
    }

    // MARK: Match decoding

    private static func chapterNumberFromMatch(_ match: NSTextCheckingResult, in source: String) -> Double {
        let initial = Double(group(match, at: 1, in: source)!)!
        let subChapterDecimal = group(match, at: 2, in: source) // includes leading dot ".5"
        let subChapterAlpha = group(match, at: 3, in: source)   // ".a" / "extra"
        return initial + checkForDecimal(subChapterDecimal, subChapterAlpha)
    }

    private static func checkForDecimal(_ decimal: String?, _ alpha: String?) -> Double {
        if let decimal, !decimal.isEmpty {
            // `decimal` always starts with a dot; Swift `Double(".5")` is nil, so prepend "0".
            return Double("0" + decimal)!
        }
        if let alpha, !alpha.isEmpty {
            if alpha.contains("extra") { return 0.99 }
            if alpha.contains("omake") { return 0.98 }
            if alpha.contains("special") { return 0.97 }
            let trimmedAlpha = alpha.drop(while: { $0 == "." }) // strips ALL leading dots
            if trimmedAlpha.count == 1 {
                return parseAlphaPostFix(trimmedAlpha.first!)
            }
        }
        return 0.0
    }

    private static func parseAlphaPostFix(_ alpha: Character) -> Double {
        guard let ascii = alpha.asciiValue else { return 0.0 }
        let number = Int(ascii) - (Int(Character("a").asciiValue!) - 1) // 'a'->1 ... 'i'->9
        if number >= 10 { return 0.0 }                                  // 'j'..'z' -> 0.0
        return Double(number) / 10.0
    }

    // MARK: NSRegularExpression helpers

    private static func allMatches(_ regex: NSRegularExpression, in string: String) -> [NSTextCheckingResult] {
        let range = NSRange(string.startIndex..., in: string)
        return regex.matches(in: string, range: range)
    }

    private static func firstMatch(_ regex: NSRegularExpression, in string: String) -> NSTextCheckingResult? {
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range)
    }

    private static func replaceAll(_ regex: NSRegularExpression, in string: String, with template: String) -> String {
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: template)
    }

    /// Returns the captured group `index`, or nil when the group did not participate.
    private static func group(_ match: NSTextCheckingResult, at index: Int, in source: String) -> String? {
        let nsRange = match.range(at: index)
        if nsRange.location == NSNotFound { return nil }
        guard let range = Range(nsRange, in: source) else { return nil }
        return String(source[range])
    }
}
