# Context Pack — Domain Layer Port (verbatim from Mihon source)

## ⚠️ REVIEW CORRECTIONS — read first, these supersede anything below

A 3-lens plan review audited this pack against source. Apply these:

1. **Foundation IS allowed.** MihonCore may `import Foundation` — it's
   cross-platform (Linux/Windows), already used by `SManga.swift`/`SourceID`, and
   the Linux CI gate is the real "no Apple-only framework" enforcer. Banned:
   UIKit, SwiftUI, JavaScriptCore, CoreData, CoreGraphics — NOT Foundation.
2. **ChapterRecognition regex engine = `NSRegularExpression`** (ICU), NOT Swift's
   native `Regex`/regex-literals — the `basic` pattern uses a lookbehind
   `(?<=ch\.)` that Swift's engine doesn't support. Build the 4 patterns once as
   `static let` from **raw string literals** (`#"..."#`). Use `matches(in:...)`
   for findAll and `stringByReplacingMatches` for replace.
3. **`Double(".5")` fix (exact):** group 2 always starts with a dot, so
   `Double("0" + decimal)!` (`"0"+".5"` = `"0.5"` → 0.5). And port Kotlin
   `alpha.trimStart('.')` as `alpha.drop(while: { $0 == "." })` (strips ALL
   leading dots), not `hasPrefix`/`removeFirst`.
4. **ChapterSort stable tiebreak:** Swift `sorted(by:)` isn't stable. Break ties
   by **original index ASCENDING, always** (independent of sort direction —
   direction lives only in the primary compare). And the NUMBER branch compares
   `Double` — implement a Kotlin-`Double.compareTo`-faithful 3-way compare
   (NaN-safe) so Swift's sort can't trap on inconsistent ordering.
5. **`memo` type:** define one shared `enum JSONValue: Codable, Hashable,
   Sendable` (object/array/string/number/bool/null), default `.object([:])`. Use
   it for `Manga.memo`, `Chapter.memo`, and `SManga.memo`. **Pin this in Wave 1**
   — `ShouldUpdateDbChapter` compares `memo != memo` and needs it Equatable.
6. **FetchInterval `floorDiv` (exact):**
   `func floorDiv(_ a: Int, _ b: Int) -> Int { let q=a/b, r=a%b; return (r != 0 && (r<0) != (b<0)) ? q-1 : q }`
   (Swift `/` and `%` truncate toward zero — wrong for negatives). Divisor uses
   `abs(interval)` (not `.magnitude`, which is UInt). Also: Kotlin `.distinct()`
   is **order-preserving** — port as array + seen-Set, NOT `Set` (order changes
   which dates survive `take(window)` and shifts the median). And `toMangaUpdate`
   short-circuits: `interval = fetchInterval < 0 ? fetchInterval : calculateInterval(...)`
   (negative = user-locked, skips the calc).
7. **v1 FetchInterval includes the real date bucketing** (epochMillis →
   start-of-day in an injected `TimeZone` → whole-day deltas) so Mihon's upstream
   `FetchIntervalTest` vectors run verbatim. Use Foundation `Calendar` with a
   fixed UTC `TimeZone`; inject the "now" reference for testability.
8. **History defaults:** fields `id:Int64, chapterId:Int64, readAt:Int64?(epoch
   millis), readDuration:Int64`; `create()` = id -1, chapterId -1, readAt nil,
   readDuration -1. (§7 said "etc." — this is the full set.)
9. **`Manga.expectedNextUpdate`:** COMPLETED = 2; returns nil when `status == 2`,
   else `nextUpdate`.
10. **Existing-stub collision:** `Repositories.swift` currently declares a minimal
    `struct Manga` — Wave 1 must DELETE it (the new `Model/Manga.swift` is the
    Manga; same module, no import). `ChapterUpdate` lives ONLY in `Chapter.swift`.

**Golden vectors = Mihon's own upstream tests** (authoritative oracle, produced by
the real Kotlin engine — NOT a Python re-impl, which would be a third regex
engine). Ported into `GoldenVectorTests`:
- ChapterRecognition: the ~50 `assertChapter` cases (incl. `"Ch.191-200 Read
  Online"`→191.200, `"Fairy Tail 404.extravol002"`→404.99, `"Mag Version
  195.5"`→195.5, `"Onepunch-Man Punch Ver002 028"`→28.0, unparseable→-1.0).
- LibrarySort: `LastRead+Asc + DateAdded+Asc` → `0b01011100`; `DateAdded+Asc`
  → `0b01011100`; `UnreadCount+Desc` → `0b00001100`; default → `0b01000000`.
- FetchInterval: from `FetchIntervalTest` — every-1-day→1, every-2-day→2, <8
  chapters big-gap→7, multiple-in-1-day→7, 43h→2, 25h→1, no-upload-dates→7.
- SetMangaChapterFlags: add state-transition vectors (tap-active→flip-dir;
  tap-new→set-mode+reset-ASC; rebuild-from-0) — currently only self-tested.

---

Ground truth for building `MihonCore`'s domain layer. Extracted from the real
Mihon Kotlin via a 5-lane read-only workflow. **Read this instead of the raw
Kotlin.** Everything in `code` blocks is copied verbatim; the bit masks, regex,
and comparators MUST be reproduced exactly — they cross the `.tachibk` backup
and DB boundaries, so a paraphrase silently corrupts user data.

All types are **platform-agnostic** (no Apple framework). Kotlin→Swift: `Long`→
`Int64`, `Int`→`Int`, `Boolean`→`Bool`, `Float`→`Float`, `Double`→`Double`,
`String?`→`String?`, enum→enum.

---

## 1. `chapterFlags` bit layout (Manga) — HIGHEST bit-exactness risk

Packed into one `Int64`. Non-contiguous fields; **bit 7 unused, gap bits 10–19**.

```
CHAPTER_SORT_DESC            = 0x00000000   // sort direction bit 0 = 0  → DESCENDING (the DEFAULT!)
CHAPTER_SORT_ASC            = 0x00000001   // bit 0 = 1 → ASCENDING
CHAPTER_SORT_DIR_MASK       = 0x00000001   // bit 0
CHAPTER_SHOW_UNREAD        = 0x00000002   // unread filter ENABLED_IS  (bit 1)
CHAPTER_SHOW_READ          = 0x00000004   // unread filter ENABLED_NOT (bit 2)
CHAPTER_UNREAD_MASK        = 0x00000006   // bits 1–2
CHAPTER_SHOW_DOWNLOADED    = 0x00000008   // bit 3
CHAPTER_SHOW_NOT_DOWNLOADED= 0x00000010   // bit 4
CHAPTER_DOWNLOADED_MASK    = 0x00000018   // bits 3–4
CHAPTER_SHOW_BOOKMARKED    = 0x00000020   // bit 5
CHAPTER_SHOW_NOT_BOOKMARKED= 0x00000040   // bit 6
CHAPTER_BOOKMARKED_MASK    = 0x00000060   // bits 5–6
CHAPTER_SORTING_SOURCE     = 0x00000000   // sort mode (bits 8–9), DEFAULT
CHAPTER_SORTING_NUMBER     = 0x00000100
CHAPTER_SORTING_UPLOAD_DATE= 0x00000200
CHAPTER_SORTING_ALPHABET   = 0x00000300
CHAPTER_SORTING_MASK       = 0x00000300   // bits 8–9
CHAPTER_DISPLAY_NAME       = 0x00000000   // display mode (bit 20)
CHAPTER_DISPLAY_NUMBER     = 0x00100000
CHAPTER_DISPLAY_MASK       = 0x00100000   // bit 20
```
Source: `manga/model/Manga.kt:87–113`.

**Universal read-modify-write** — every mutation goes through this. Kotlin infix
`and`/`or` are strict left-to-right; port with **explicit parens** and the
`(flag & mask)` guard:
```kotlin
private fun Long.setFlag(flag: Long, mask: Long): Long {
    return this and mask.inv() or (flag and mask)   // == (this & ~mask) | (flag & mask)
}
```
Getters (keep values **in place**, do NOT `>>` shift them down — they're compared
against the constants directly):
```kotlin
val sorting: Long           get() = chapterFlags and CHAPTER_SORTING_MASK
val displayMode: Long       get() = chapterFlags and CHAPTER_DISPLAY_MASK
val unreadFilterRaw: Long   get() = chapterFlags and CHAPTER_UNREAD_MASK
val downloadedFilterRaw     = chapterFlags and CHAPTER_DOWNLOADED_MASK
val bookmarkedFilterRaw     = chapterFlags and CHAPTER_BOOKMARKED_MASK
fun sortDescending(): Boolean = chapterFlags and CHAPTER_SORT_DIR_MASK == CHAPTER_SORT_DESC
```
TriState decode (note **0x6 invalid combo → DISABLED** via `else`):
```kotlin
val unreadFilter: TriState get() = when (unreadFilterRaw) {
    CHAPTER_SHOW_UNREAD -> TriState.ENABLED_IS
    CHAPTER_SHOW_READ   -> TriState.ENABLED_NOT
    else                -> TriState.DISABLED
}
// bookmarkedFilter: same pattern with SHOW_BOOKMARKED / SHOW_NOT_BOOKMARKED.
// Manga.kt has downloadedFilterRaw but NO downloadedFilter TriState getter (app layer).
```

**TriState** (`core/common/.../preference/TriState.kt`) — ordinals DISABLED=0,
ENABLED_IS=1, ENABLED_NOT=2. **These ordinals are NOT the persisted bits** (the
persisted values are the 0x2/0x4 constants). Helpers:
```kotlin
inline fun applyFilter(filter: TriState, predicate: () -> Boolean): Boolean = when (filter) {
    TriState.DISABLED -> true
    TriState.ENABLED_IS -> predicate()
    TriState.ENABLED_NOT -> !predicate()
}
fun next(): TriState = when (this) { DISABLED->ENABLED_IS; ENABLED_IS->ENABLED_NOT; ENABLED_NOT->DISABLED }
```

**Landmines:** default `chapterFlags=0` ⇒ source-order + descending-flag ⇒ natural
ascending source order. Direction is a BIT not a Bool; descending is bit-*clear*.
Never write the TriState ordinal into the flags. `viewerFlags` is opaque here (no
domain helpers — decoded in the app/reader layer; do NOT invent masks).

---

## 2. `SetMangaChapterFlags` behavior (`manga/interactor/SetMangaChapterFlags.kt`)

```kotlin
// tap active sort mode → flip direction; tap new mode → set it AND reset to ASC:
val newFlags = manga.chapterFlags.let {
    if (manga.sorting == flag) {
        val orderFlag = if (manga.sortDescending()) Manga.CHAPTER_SORT_ASC else Manga.CHAPTER_SORT_DESC
        it.setFlag(orderFlag, Manga.CHAPTER_SORT_DIR_MASK)
    } else {
        it.setFlag(flag, Manga.CHAPTER_SORTING_MASK).setFlag(Manga.CHAPTER_SORT_ASC, Manga.CHAPTER_SORT_DIR_MASK)
    }
}
// rebuild whole field from 0:
chapterFlags = 0L.setFlag(unreadFilter, CHAPTER_UNREAD_MASK)
    .setFlag(downloadedFilter, CHAPTER_DOWNLOADED_MASK)
    .setFlag(bookmarkedFilter, CHAPTER_BOOKMARKED_MASK)
    .setFlag(sortingMode, CHAPTER_SORTING_MASK)
    .setFlag(sortingDirection, CHAPTER_SORT_DIR_MASK)
    .setFlag(displayMode, CHAPTER_DISPLAY_MASK)
```

---

## 3. Category `flags` = LibrarySort only (`library/model/LibrarySortMode.kt`, `Flag.kt`)

Display mode is NOT bit-packed (it's a preference string). Category.flags packs
sort only: **Type = bits 2–5 (mask 0b00111100), Direction = bit 6 (0b01000000)**.
Bits 0–1 legacy/unused.

```
Type.mask   = 0b00111100      Direction.mask = 0b01000000
Type.Alphabetical   = 0b00000000    LastRead      = 0b00000100
LastUpdate          = 0b00001000    UnreadCount   = 0b00001100
TotalChapters       = 0b00010000    LatestChapter = 0b00010100
ChapterFetchDate    = 0b00011000    DateAdded     = 0b00011100
TrackerMean         = 0b00100000    Random        = 0b00111100  (== full type mask)
Direction.Ascending  = 0b01000000  (SET bit!)   Descending = 0b00000000
default = Alphabetical + Ascending → flag 0b01000000
```
Packing operators (same RMW; `and` binds tighter than `or`):
```kotlin
operator fun Long.plus(other: Flag): Long =
    if (other is Mask) this and other.mask.inv() or (other.flag and other.mask) else this or other.flag
operator fun Long.contains(other: Flag): Boolean =
    if (other is Mask) other.flag == this and other.mask else other.flag == this
// decode: Type = types.find { it.flag == flag and Type.mask } ?: Alphabetical
//         Direction = directions.find { it.flag == flag and Direction.mask } ?: Ascending
// encode: LibrarySort.flag = type + direction ; null flags → default
```
Test vectors: DateAdded+Ascending → 0b01011100; UnreadCount+Descending → 0b00001100;
default → 0b01000000.

String form `"TYPE,DIRECTION"` (`.tachibk`/pref). **Name trap: LastUpdate ↔
"LAST_MANGA_UPDATE"** (not "LAST_UPDATE"). Empty/parse-fail → default; unknown
type → Alphabetical; direction Ascending only if exactly `"ASCENDING"`.

**LibraryDisplayMode** (string, not bits): `"COMPACT_GRID"`, `"COMFORTABLE_GRID"`,
`"LIST"`, `"COVER_ONLY_GRID"`; anything else → CompactGrid (default).

**Landmine:** Ascending = bit SET (inverted from intuition). Direction 0 = Descending.

---

## 4. ChapterRecognition (`chapter/service/ChapterRecognition.kt`) — port verbatim

```kotlin
private const val NUMBER_PATTERN = """([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?"""
private val basic  = Regex("""(?<=ch\.) *$NUMBER_PATTERN""")
private val number = Regex(NUMBER_PATTERN)
private val unwanted = Regex("""\b(?:v|ver|vol|version|volume|season|s)[^a-z]?[0-9]+""")
private val unwantedWhiteSpace = Regex("""\s(?=extra|special|omake)""")

fun parseChapterNumber(mangaTitle: String, chapterName: String, chapterNumber: Double? = null): Double {
    if (chapterNumber != null && (chapterNumber == -2.0 || chapterNumber > -1.0)) return chapterNumber
    val cleanChapterName = chapterName.lowercase()
        .replace(mangaTitle.lowercase(), "").trim()
        .replace(',', '.').replace('-', '.')
        .replace(unwantedWhiteSpace, "")
    val numberMatch = number.findAll(cleanChapterName)
    when {
        numberMatch.none() -> return chapterNumber ?: -1.0
        numberMatch.count() > 1 -> {
            unwanted.replace(cleanChapterName, "").let { name ->
                basic.find(name)?.let { return getChapterNumberFromMatch(it) }
                number.find(name)?.let { return getChapterNumberFromMatch(it) }
            }
        }
    }
    return getChapterNumberFromMatch(numberMatch.first())
}
private fun getChapterNumberFromMatch(match: MatchResult): Double {
    val initial = match.groups[1]?.value?.toDouble()!!
    val subChapterDecimal = match.groups[2]?.value      // includes leading dot ".5"
    val subChapterAlpha   = match.groups[3]?.value      // ".a" / "extra"
    return initial + checkForDecimal(subChapterDecimal, subChapterAlpha)
}
private fun checkForDecimal(decimal: String?, alpha: String?): Double {
    if (!decimal.isNullOrEmpty()) return decimal.toDouble()   // Kotlin parses ".5" → 0.5
    if (!alpha.isNullOrEmpty()) {
        if (alpha.contains("extra"))   return 0.99
        if (alpha.contains("omake"))   return 0.98
        if (alpha.contains("special")) return 0.97
        val trimmedAlpha = alpha.trimStart('.')
        if (trimmedAlpha.length == 1) return parseAlphaPostFix(trimmedAlpha[0])
    }
    return 0.0
}
private fun parseAlphaPostFix(alpha: Char): Double {
    val number = alpha.code - ('a'.code - 1)   // 'a'→1 … 'i'→9
    if (number >= 10) return 0.0               // 'j'..'z' → 0.0
    return number / 10.0
}
```

**Swift traps (critical):**
- `Double(".5")` returns **nil** in Swift (Kotlin gives 0.5). Prepend `"0"` or
  handle the leading-dot form explicitly.
- `numberMatch` is a lazy Sequence; `.none()/.count()/.first()` re-scan it.
  Materialize matches **once** into an array; use `isEmpty`/`count`/`first`.
- The final `numberMatch.first()` is on the ORIGINAL cleaned name, not the
  tag-stripped `name` used inside the count>1 branch.
- Substitutions: `','→'.'` and `'-'→'.'` happen **before** matching, so a range
  `"10-11"` becomes `"10.11"` → one match → 10.11.
- `unwanted` alternation is exactly `v|ver|vol|version|volume|season|s` with a
  SINGLE optional separator `[^a-z]?` (not `*`). **`volume` is required** — `vol`
  does NOT match `volume64` (after `vol`, the `[^a-z]?` matches empty and `[0-9]+`
  sees `u`, failing), so dropping `volume` leaves the tag un-stripped and
  mis-parses the number.
- Known-number guard is strict `> -1.0` (not `>=`), plus the `-2.0` sentinel.

---

## 5. Chapter sort (`chapter/service/ChapterSort.kt`) — SOURCE case is INVERTED

```kotlin
fun getChapterSort(manga: Manga, sortDescending: Boolean = manga.sortDescending()): (Chapter, Chapter) -> Int {
    return when (manga.sorting) {
        Manga.CHAPTER_SORTING_SOURCE -> when (sortDescending) {
            true  -> { c1, c2 -> c1.sourceOrder.compareTo(c2.sourceOrder) }   // INVERTED vs others
            false -> { c1, c2 -> c2.sourceOrder.compareTo(c1.sourceOrder) }
        }
        Manga.CHAPTER_SORTING_NUMBER -> when (sortDescending) {
            true  -> { c1, c2 -> c2.chapterNumber.compareTo(c1.chapterNumber) }
            false -> { c1, c2 -> c1.chapterNumber.compareTo(c2.chapterNumber) }
        }
        Manga.CHAPTER_SORTING_UPLOAD_DATE -> when (sortDescending) {
            true  -> { c1, c2 -> c2.dateUpload.compareTo(c1.dateUpload) }
            false -> { c1, c2 -> c1.dateUpload.compareTo(c2.dateUpload) }
        }
        Manga.CHAPTER_SORTING_ALPHABET -> when (sortDescending) {
            true  -> { c1, c2 -> c2.name.compareToWithCollator(c1.name) }
            false -> { c1, c2 -> c1.name.compareToWithCollator(c2.name) }
        }
        else -> throw NotImplementedError("Invalid chapter sorting method: ${manga.sorting}")
    }
}
```
**Landmines:** SOURCE inverts the sign relative to the other three — replicate each
branch literally, do NOT use one generic flip. No secondary tie-break (relies on a
STABLE sort — Swift `sort` is not stable, so add an index tiebreak or use a stable
sort). Alphabet uses a locale collator (not raw String compare) — for v1 use
`localizedStandardCompare`/`localizedCompare`; note as an approximation.

---

## 6. FetchInterval (`manga/interactor/FetchInterval.kt`) — median-of-day-deltas

```kotlin
const val MAX_INTERVAL = 28
private const val GRACE_PERIOD = 1L

internal fun calculateInterval(chapters: List<Chapter>, zone: ZoneId): Int {
    val chapterWindow = if (chapters.size <= 8) 3 else 10
    val uploadDates = chapters.asSequence().filter { it.dateUpload > 0L }
        .sortedByDescending { it.dateUpload }
        .map { /* epochMilli → LocalDate start-of-day in zone */ }.distinct().take(chapterWindow).toList()
    val fetchDates = chapters.asSequence()              // NOTE: no >0 filter on fetch
        .sortedByDescending { it.dateFetch }
        .map { /* start-of-day */ }.distinct().take(chapterWindow).toList()
    val interval = when {
        uploadDates.size >= 3 -> {
            val ranges = uploadDates.windowed(2).map { x -> x[1].until(x[0], DAYS) }.sorted()
            ranges[(ranges.size - 1) / 2].toInt()       // integer median, LOWER-middle
        }
        fetchDates.size >= 3 -> {
            val ranges = fetchDates.windowed(2).map { x -> x[1].until(x[0], DAYS) }.sorted()
            ranges[(ranges.size - 1) / 2].toInt()
        }
        else -> 7
    }
    return interval.coerceIn(1, MAX_INTERVAL)            // Swift: min(max(interval,1),28)
}

private fun calculateNextUpdate(manga, interval: Int, dateTime, window: Pair<Long,Long>): Long {
    if (manga.nextUpdate in window.first..(window.second + 1)) return manga.nextUpdate  // inclusive
    val latestDate = /* start-of-day of (lastUpdate>0 ? lastUpdate : now) */
    val timeSinceLatest = DAYS.between(latestDate, dateTime).toInt()
    val cycle = timeSinceLatest.floorDiv(
        interval.absoluteValue.takeIf { interval < 0 }                 // negative = user-locked → raw |interval|
            ?: increaseInterval(interval, timeSinceLatest, increaseWhenOver = 10)
    )
    return /* latestDate + (cycle+1)*|interval| days → epoch millis */
}
private fun increaseInterval(delta: Int, timeSinceLatest: Int, increaseWhenOver: Int): Int {
    if (delta >= MAX_INTERVAL) return MAX_INTERVAL
    val cycle = timeSinceLatest.floorDiv(delta) + 1
    return if (cycle > increaseWhenOver) increaseInterval(delta * 2, timeSinceLatest, increaseWhenOver) else delta
}
```
**Landmines:** window boundary is `<= 8 → 3 else 10`. Median index `(size-1)/2`
(integer, lower-middle). Negative `fetchInterval` is a **user-locked sentinel** —
divisor uses raw `|interval|`. `floorDiv` is true floor (Swift `/` truncates toward
zero — implement floor for negatives). The date math needs day-granular
start-of-day in a given timezone; the **pure algorithm** (windowing, median,
backoff, clamp) is what we port + test now; wrap the date/zone at the edge so the
core stays testable with injected day-deltas.

---

## 7. Entities (fields · type · default)

**Manga** (`manga/model/Manga.kt`) — 25 fields:
id:Int64=-1, source:Int64=-1, favorite:Bool=false, lastUpdate:Int64=0,
nextUpdate:Int64=0, fetchInterval:Int=0, dateAdded:Int64=0, viewerFlags:Int64=0,
chapterFlags:Int64=0, coverLastModified:Int64=0, url:String="", title:String="",
artist:String?=nil, author:String?=nil, description:String?=nil, genre:[String]?=nil,
status:Int64=0, thumbnailUrl:String?=nil, updateStrategy:UpdateStrategy=alwaysUpdate,
initialized:Bool=false, lastModifiedAt:Int64=0, favoriteModifiedAt:Int64?=nil,
version:Int64=0, notes:String="" (non-optional), memo:(JSON, default empty).
`sortDescending()`, filter/sorting/displayMode getters live here (§1).
`expectedNextUpdate` = nextUpdate unless status==COMPLETED.
`MangaUpdate` = all-nullable partial (id required) MINUS lastModifiedAt &
favoriteModifiedAt.

**Chapter** (`chapter/model/Chapter.kt`): id, mangaId, read:Bool, bookmark:Bool,
lastPageRead:Int64, dateFetch:Int64, sourceOrder:Int64, url, name, dateUpload:Int64,
chapterNumber:**Double**, scanlator:String?, lastModifiedAt:Int64, version:Int64,
memo. `create()` defaults: **version=1** (not 0), dateUpload=-1, chapterNumber=-1.0.
`isRecognizedNumber = chapterNumber >= 0`. `copyFrom` normalizes blank scanlator→nil.

**Category** (`category/model/Category.kt`): id:Int64, name:String, order:Int64,
flags:Int64. `UNCATEGORIZED_ID = 0`; `isSystemCategory = id == 0`.

**Track** (`track/model/Track.kt`): NO create()/defaults (all required). Fields
incl. libraryId:Int64?, status:Int64, score:Double, lastChapterRead:Double, etc.

**History** (`history/model/History.kt`): readAt:Date?**(nullable)**, readDuration,
etc. Model `readAt` as an optional epoch-millis Int64? in the platform-agnostic
core (avoid Foundation.Date at the boundary).

---

## 8. Repository protocols (async throws for suspend; AsyncStream for Flow)

Verbatim signatures captured for Manga/Chapter/Category/History/Track (Lane 5).
Ancillary types referenced: LibraryManga, MangaWithChapterCount, ChapterUpdate,
CategoryUpdate, HistoryUpdate, HistoryWithRelations — define minimal placeholders
now (fill later). `applyScanlatorFilter` defaults to false. `updateAllFlags(Int64?)`
is nullable. `delete(mangaId, trackerId)` keys on the pair.

---

## 9. Interactor classification (Lane 5)

**Real logic (port + test):** FetchInterval, SetMangaChapterFlags,
ShouldUpdateDbChapter (6-field dirty compare: scanlator/name/dateUpload/
chapterNumber/sourceOrder/memo), GetNextChapters, CreateCategoryWithName
(initialFlags = sort.type|direction; nextOrder = max(order)+1 ?? 0),
ReorderCategory, GetChapterSort.
**Thin delegation (skip / inline):** GetManga, GetFavorites, GetChapter, most
Get*/Set*/Update* — they forward to a repository. (One exception:
GetChaptersByMangaId swallows exceptions → emptyList.)
