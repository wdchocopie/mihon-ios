import Foundation

/// Pure transformations on a manga's `chapterFlags` bitfield, ported from
/// `manga/interactor/SetMangaChapterFlags.kt`. Every mutation goes through the
/// universal `Manga.setFlag(_:flag:mask:)` read-modify-write so stray bits never
/// leak across the non-contiguous flag fields.
public enum SetMangaChapterFlags {

    /// Tap a sort mode: if `mode` is already the active sort, flip the direction
    /// bit; otherwise switch to `mode` AND reset the direction to ascending.
    ///
    /// - Parameters:
    ///   - current: the current `chapterFlags`.
    ///   - mode: one of `Manga.chapterSortingSource/Number/UploadDate/Alphabet`
    ///     (already positioned within `chapterSortingMask`).
    /// - Returns: the new `chapterFlags`.
    public static func toggleSortingModeOrFlipOrder(current: Int64, mode: Int64) -> Int64 {
        if (current & Manga.chapterSortingMask) == mode {
            // Active mode tapped → flip direction. `sortDescending` == direction
            // bit CLEARED, so descending → set ASC, ascending → set DESC.
            let descending = (current & Manga.chapterSortDirMask) == Manga.chapterSortDesc
            let orderFlag = descending ? Manga.chapterSortAsc : Manga.chapterSortDesc
            return Manga.setFlag(current, flag: orderFlag, mask: Manga.chapterSortDirMask)
        } else {
            // New mode → set it, then reset direction to ascending.
            let withMode = Manga.setFlag(current, flag: mode, mask: Manga.chapterSortingMask)
            return Manga.setFlag(withMode, flag: Manga.chapterSortAsc, mask: Manga.chapterSortDirMask)
        }
    }

    /// Rebuild the whole `chapterFlags` field from 0 via chained `setFlag`, in the
    /// exact order Mihon uses (unread → downloaded → bookmarked → sorting → sort
    /// direction → display).
    ///
    /// Each argument must already be positioned within its mask (e.g. pass
    /// `Manga.chapterShowUnread`, `Manga.chapterSortingNumber`, `Manga.chapterSortAsc`).
    public static func setAllFlags(
        unread: Int64,
        downloaded: Int64,
        bookmarked: Int64,
        sortingMode: Int64,
        sortingDirection: Int64,
        displayMode: Int64
    ) -> Int64 {
        var flags: Int64 = 0
        flags = Manga.setFlag(flags, flag: unread, mask: Manga.chapterUnreadMask)
        flags = Manga.setFlag(flags, flag: downloaded, mask: Manga.chapterDownloadedMask)
        flags = Manga.setFlag(flags, flag: bookmarked, mask: Manga.chapterBookmarkedMask)
        flags = Manga.setFlag(flags, flag: sortingMode, mask: Manga.chapterSortingMask)
        flags = Manga.setFlag(flags, flag: sortingDirection, mask: Manga.chapterSortDirMask)
        flags = Manga.setFlag(flags, flag: displayMode, mask: Manga.chapterDisplayMask)
        return flags
    }
}
