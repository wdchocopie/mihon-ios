import Foundation

/// The chapter-sync merge — the pure core of `SyncChaptersWithSource`, the logic
/// that reconciles a source's chapter list against the DB. It decides what to
/// add / update / delete and, crucially, inherits read & bookmark state from
/// deleted chapters onto re-added ones (so a re-uploaded chapter a user already
/// read stays read). Getting this wrong corrupts a user's read progress.
///
/// This is the **pure computation**: side effects (the actual repo writes, the
/// download-file rename, `HttpSource.prepareNewChapter`, the fetch-interval
/// update) are the caller's job. `ShouldUpdateDbChapter` is injected so the
/// dirty-check stays swappable in tests.
public enum ChapterSync {

    public struct Result: Sendable, Equatable {
        /// New chapters to insert (no id yet), with dateFetch/read/bookmark resolved.
        public var toAdd: [Chapter]
        /// Existing DB chapters whose fields changed (caller → ChapterUpdate).
        public var toUpdate: [Chapter]
        /// Ids of chapters no longer offered by the source.
        public var toDeleteIds: [Int64]
        /// URLs among `toAdd` that were auto-marked read or are duplicates —
        /// excluded from the "newly added" notification set.
        public var changedOrDuplicateReadUrls: Set<String>

        public var hasChanges: Bool {
            !toAdd.isEmpty || !toUpdate.isEmpty || !toDeleteIds.isEmpty
        }
    }

    public static func compute(
        rawSourceChapters: [SChapter],
        manga: Manga,
        dbChapters: [Chapter],
        nowMillis: Int64,
        markDuplicateAsRead: Bool = false,
        shouldUpdate: (_ db: Chapter, _ source: Chapter) -> Bool = ShouldUpdateDbChapter.shouldUpdate
    ) -> Result {
        // Build the normalized source chapters: dedup by url, map onto Chapter,
        // sanitize the name, set mangaId + sourceOrder.
        var seenURLs = Set<String>()
        let distinctSource = rawSourceChapters.filter { seenURLs.insert($0.url).inserted }
        let sourceChapters: [Chapter] = distinctSource.enumerated().map { i, sc in
            var c = Chapter().copyFrom(sChapter: sc)
            c.name = ChapterSanitizer.sanitize(sc.name, title: manga.title)
            c.mangaId = manga.id
            c.sourceOrder = Int64(i)
            return c
        }

        let sourceURLs = Set(sourceChapters.map(\.url))
        let removedChapters = dbChapters.filter { !sourceURLs.contains($0.url) }

        var newChapters: [Chapter] = []
        var updatedChapters: [Chapter] = []
        var maxSeenUploadDate: Int64 = 0

        for var chapter in sourceChapters {
            // (HttpSource.prepareNewChapter is a source-runtime side effect — omitted.)
            chapter.chapterNumber = ChapterRecognition.parseChapterNumber(
                mangaTitle: manga.title, chapterName: chapter.name, chapterNumber: chapter.chapterNumber
            )

            if let dbChapter = dbChapters.first(where: { $0.url == chapter.url }) {
                if shouldUpdate(dbChapter, chapter) {
                    // (download-file rename is a side effect — omitted.)
                    var toChange = dbChapter
                    toChange.name = chapter.name
                    toChange.chapterNumber = chapter.chapterNumber
                    toChange.scanlator = chapter.scanlator
                    toChange.sourceOrder = chapter.sourceOrder
                    toChange.memo = chapter.memo
                    if chapter.dateUpload != 0 { toChange.dateUpload = chapter.dateUpload }
                    updatedChapters.append(toChange)
                }
            } else {
                if chapter.dateUpload == 0 {
                    chapter.dateUpload = maxSeenUploadDate == 0 ? nowMillis : maxSeenUploadDate
                } else {
                    maxSeenUploadDate = max(maxSeenUploadDate, chapter.dateUpload)
                }
                newChapters.append(chapter)
            }
        }

        // Nothing changed → the caller still updates the fetch interval.
        if newChapters.isEmpty && removedChapters.isEmpty && updatedChapters.isEmpty {
            return Result(toAdd: [], toUpdate: [], toDeleteIds: [], changedOrDuplicateReadUrls: [])
        }

        // Read/bookmark inheritance from deleted chapters, keyed by chapter number.
        var deletedChapterNumbers = Set<Double>()
        var deletedReadChapterNumbers = Set<Double>()
        var deletedBookmarkedChapterNumbers = Set<Double>()
        for c in removedChapters {
            if c.read { deletedReadChapterNumbers.insert(c.chapterNumber) }
            if c.bookmark { deletedBookmarkedChapterNumbers.insert(c.chapterNumber) }
            deletedChapterNumbers.insert(c.chapterNumber)
        }

        let readChapterNumbers = Set(
            dbChapters.filter { $0.read && $0.isRecognizedNumber }.map(\.chapterNumber)
        )

        // For a re-added chapter number, reuse the original entry's fetch date so it
        // doesn't pollute the Updates tab. Duplicate numbers: lowest dateFetch wins
        // (matches Kotlin sortedByDescending + associate, where the last write sticks).
        var deletedDateFetchByNumber: [Double: Int64] = [:]
        for c in removedChapters.sorted(by: { $0.dateFetch > $1.dateFetch }) {
            deletedDateFetchByNumber[c.chapterNumber] = c.dateFetch
        }

        var changedOrDuplicateReadUrls = Set<String>()
        let count = newChapters.count
        let toAdd: [Chapter] = newChapters.enumerated().map { idx, item in
            var chapter = item
            // Descending dateFetch: sources return most-recent first, so the first
            // gets the highest value. (Kotlin `nowMillis + itemCount--`.)
            chapter.dateFetch = nowMillis + Int64(count - idx)

            if readChapterNumbers.contains(chapter.chapterNumber) && markDuplicateAsRead {
                changedOrDuplicateReadUrls.insert(chapter.url)
                chapter.read = true
            }

            guard chapter.isRecognizedNumber, deletedChapterNumbers.contains(chapter.chapterNumber) else {
                return chapter
            }

            chapter.read = deletedReadChapterNumbers.contains(chapter.chapterNumber)
            chapter.bookmark = deletedBookmarkedChapterNumbers.contains(chapter.chapterNumber)
            if let df = deletedDateFetchByNumber[chapter.chapterNumber] { chapter.dateFetch = df }
            changedOrDuplicateReadUrls.insert(chapter.url)
            return chapter
        }

        return Result(
            toAdd: toAdd,
            toUpdate: updatedChapters,
            toDeleteIds: removedChapters.map(\.id),
            changedOrDuplicateReadUrls: changedOrDuplicateReadUrls
        )
    }

    /// After the caller inserts `toAdd` (assigning ids), the chapters to surface as
    /// "newly added" are those not auto-read/duplicate and not from an excluded
    /// scanlator. Ports the final `filterNot { url in ... || scanlator in ... }`.
    public static func newlyAdded(
        added: [Chapter],
        changedOrDuplicateReadUrls: Set<String>,
        excludedScanlators: Set<String>
    ) -> [Chapter] {
        added.filter { chapter in
            if changedOrDuplicateReadUrls.contains(chapter.url) { return false }
            if let s = chapter.scanlator, excludedScanlators.contains(s) { return false }
            return true
        }
    }
}
