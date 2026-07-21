import Foundation

/// "What should I read next?" — the pure core of `GetNextChapters`. Sorts a
/// manga's chapters in ascending source order, optionally filters to unread, and
/// (given a starting chapter) returns the chapters from there on, handling the
/// "is the current chapter finished?" case exactly as Mihon does.
public enum GetNextChapters {

    /// Ports the `await(mangaId, fromChapterId, onlyUnread)` chain as one pure
    /// computation over already-fetched `chapters`.
    public static func compute(
        manga: Manga,
        chapters: [Chapter],
        fromChapterId: Int64? = nil,
        onlyUnread: Bool = true
    ) -> [Chapter] {
        let sorted = sortedChapters(chapters, for: manga, sortDescending: false)
        let base = onlyUnread ? sorted.filter { !$0.read } : sorted

        guard let fromId = fromChapterId else { return base }

        let currentIndex = base.firstIndex(where: { $0.id == fromId }) ?? -1
        let start = max(0, currentIndex)
        let nextChapters = start < base.count ? Array(base[start...]) : []

        if onlyUnread { return nextChapters }

        // The "next" chapter is the current one if unfinished, otherwise the ones
        // after it.
        let fromChapter = (currentIndex >= 0 && currentIndex < base.count) ? base[currentIndex] : nil
        if let fromChapter, !fromChapter.read {
            return nextChapters
        }
        return Array(nextChapters.dropFirst())
    }
}
