import Foundation

/// Fetch-interval estimation, ported from Mihon's
/// `domain/.../manga/interactor/FetchInterval.kt`.
///
/// The core algorithm predicts how often a series releases new chapters by taking
/// the **median of whole-day deltas** between recent chapter dates. It prefers the
/// source-provided upload dates and falls back to client fetch dates, then to a
/// 7-day default. The result is always clamped to `1...MAX_INTERVAL`.
///
/// Date handling is real: epoch-millis are bucketed to local start-of-day in an
/// **injected** `TimeZone` (via Foundation `Calendar`) so Mihon's upstream
/// `FetchIntervalTest` vectors reproduce verbatim. The "now" reference used by
/// `calculateNextUpdate` is injected for testability. No Apple-only frameworks —
/// only cross-platform `Foundation`.
public enum FetchInterval {

    /// Maximum interval in days. Matches Kotlin `MAX_INTERVAL = 28`.
    public static let maxInterval = 28

    /// Grace period (days) used when computing the update window. Matches Kotlin
    /// `GRACE_PERIOD = 1L`.
    public static let gracePeriod: Int64 = 1

    // MARK: - calculateInterval

    /// Estimate the release interval (in days) for `chapters`, bucketing dates in
    /// `timeZone`. Faithful port of Kotlin `calculateInterval`.
    ///
    /// - window: `chapters.count <= 8 ? 3 : 10`.
    /// - uploadDates: filter `dateUpload > 0`, sort by `dateUpload` DESC, map to
    ///   local start-of-day, **order-preserving** distinct, take `window`.
    /// - fetchDates: same on `dateFetch` but with **no `> 0` filter**.
    /// - If `uploadDates.count >= 3` → median of pairwise day-deltas; else if
    ///   `fetchDates.count >= 3` → same on fetch dates; else 7.
    /// - Clamped to `1...maxInterval`.
    public static func calculateInterval(_ chapters: [Chapter], timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let chapterWindow = chapters.count <= 8 ? 3 : 10

        let uploadStarts = chapters
            .filter { $0.dateUpload > 0 }
            .sorted { $0.dateUpload > $1.dateUpload }        // sortedByDescending
            .map { startOfDay(millis: $0.dateUpload, calendar: calendar) }
        let uploadDates = Array(orderPreservingDistinct(uploadStarts).prefix(chapterWindow))

        let fetchStarts = chapters
            .sorted { $0.dateFetch > $1.dateFetch }          // NOTE: no > 0 filter
            .map { startOfDay(millis: $0.dateFetch, calendar: calendar) }
        let fetchDates = Array(orderPreservingDistinct(fetchStarts).prefix(chapterWindow))

        let interval: Int
        if uploadDates.count >= 3 {
            interval = median(of: sortedDayDeltas(uploadDates, calendar: calendar))
        } else if fetchDates.count >= 3 {
            interval = median(of: sortedDayDeltas(fetchDates, calendar: calendar))
        } else {
            interval = 7
        }

        return min(max(interval, 1), maxInterval)            // coerceIn(1, MAX_INTERVAL)
    }

    // MARK: - calculateNextUpdate

    /// Faithful port of Kotlin `calculateNextUpdate`. Returns the next-update epoch
    /// millis for `manga`.
    ///
    /// - dateTime: the reference "current" instant (Mihon's `ZonedDateTime`).
    /// - window: inclusive `(lower, upper)` epoch-millis bounds; if
    ///   `manga.nextUpdate` falls in `lower...(upper + 1)` it is returned unchanged.
    /// - timeZone: zone used to bucket `latestDate` to start-of-day and to add days.
    /// - now: fallback reference used when `manga.lastUpdate <= 0` (Kotlin's
    ///   `Instant.now()`), injected for testability.
    ///
    /// A **negative** `interval` is a user-locked sentinel: the divisor uses the raw
    /// `abs(interval)` instead of the recursive back-off.
    public static func calculateNextUpdate(
        manga: Manga,
        interval: Int,
        dateTime: Date,
        window: (lower: Int64, upper: Int64),
        timeZone: TimeZone,
        now: Date
    ) -> Int64 {
        if manga.nextUpdate >= window.lower && manga.nextUpdate <= window.upper + 1 {
            return manga.nextUpdate
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let latestSource: Date = manga.lastUpdate > 0
            ? Date(timeIntervalSince1970: Double(manga.lastUpdate) / 1000.0)
            : now
        let latestDate = calendar.startOfDay(for: latestSource)

        let timeSinceLatest = calendar.dateComponents([.day], from: latestDate, to: dateTime).day ?? 0

        let divisor: Int = interval < 0
            ? abs(interval)
            : increaseInterval(delta: interval, timeSinceLatest: timeSinceLatest, increaseWhenOver: 10)
        let cycle = floorDiv(timeSinceLatest, divisor)

        let daysToAdd = (cycle + 1) * abs(interval)
        let nextDate = calendar.date(byAdding: .day, value: daysToAdd, to: latestDate) ?? latestDate
        // Kotlin converts the next local-midnight with `dateTime.offset` — the
        // FIXED offset of the reference instant — not the offset in effect at
        // nextDate. Across a DST boundary those differ; correct for it so the
        // result matches Mihon for any TimeZone (a no-op in UTC).
        let fixedOffset = timeZone.secondsFromGMT(for: dateTime)
        let nextOffset = timeZone.secondsFromGMT(for: nextDate)
        let correctedSeconds = nextDate.timeIntervalSince1970 + Double(nextOffset - fixedOffset)
        return Int64((correctedSeconds * 1000).rounded())
    }

    /// Faithful port of Kotlin `increaseInterval`: recursively doubles `delta` while
    /// the projected number of missed cycles exceeds `increaseWhenOver`, capped at
    /// `maxInterval`.
    static func increaseInterval(delta: Int, timeSinceLatest: Int, increaseWhenOver: Int) -> Int {
        if delta >= maxInterval { return maxInterval }
        let cycle = floorDiv(timeSinceLatest, delta) + 1
        if cycle > increaseWhenOver {
            return increaseInterval(delta: delta * 2, timeSinceLatest: timeSinceLatest, increaseWhenOver: increaseWhenOver)
        }
        return delta
    }

    // MARK: - Helpers

    /// True floor division. Swift `/` and `%` truncate toward zero, which is wrong
    /// for negative operands; this matches Kotlin `Int.floorDiv`.
    static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        let r = a % b
        return (r != 0 && (r < 0) != (b < 0)) ? q - 1 : q
    }

    /// Bucket epoch-millis to local start-of-day in `calendar.timeZone`.
    private static func startOfDay(millis: Int64, calendar: Calendar) -> Date {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        return calendar.startOfDay(for: date)
    }

    /// Kotlin `.distinct()` is **order-preserving** — reproduce with an array + a
    /// seen-set (a plain `Set` would reorder and change which dates survive
    /// `take(window)`, shifting the median).
    private static func orderPreservingDistinct(_ dates: [Date]) -> [Date] {
        var seen = Set<Date>()
        var result: [Date] = []
        result.reserveCapacity(dates.count)
        for d in dates where seen.insert(d).inserted {
            result.append(d)
        }
        return result
    }

    /// Pairwise whole-day deltas between adjacent (descending-sorted) dates, sorted
    /// ascending. Mirrors Kotlin `windowed(2).map { x -> x[1].until(x[0], DAYS) }.sorted()`
    /// where `x[0]` is the newer date and `x[1]` the older.
    private static func sortedDayDeltas(_ dates: [Date], calendar: Calendar) -> [Int] {
        guard dates.count >= 2 else { return [] }
        var deltas: [Int] = []
        deltas.reserveCapacity(dates.count - 1)
        for i in 0..<(dates.count - 1) {
            let newer = dates[i]
            let older = dates[i + 1]
            let d = calendar.dateComponents([.day], from: older, to: newer).day ?? 0
            deltas.append(d)
        }
        return deltas.sorted()
    }

    /// Integer median at the **lower-middle** index `(count - 1) / 2`, matching
    /// Kotlin `ranges[(ranges.size - 1) / 2]`. Precondition: non-empty.
    private static func median(of sortedDeltas: [Int]) -> Int {
        sortedDeltas[(sortedDeltas.count - 1) / 2]
    }
}
