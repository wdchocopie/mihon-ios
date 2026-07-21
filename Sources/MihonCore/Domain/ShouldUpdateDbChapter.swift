import Foundation

/// Dirty-check for a chapter fetched from a source against the copy already in the
/// DB, ported from `manga/interactor/SyncChaptersWithSource` / Mihon's
/// `ShouldUpdateDbChapter`. Returns `true` when any of the six source-derived
/// fields differ, meaning the DB row needs updating.
public enum ShouldUpdateDbChapter {

    /// - Parameters:
    ///   - db: the chapter currently stored in the DB.
    ///   - source: the freshly fetched chapter from the source.
    /// - Returns: `true` if `scanlator`, `name`, `dateUpload`, `chapterNumber`,
    ///   `sourceOrder`, or `memo` differ between the two.
    public static func shouldUpdate(db: Chapter, source: Chapter) -> Bool {
        db.scanlator != source.scanlator
            || db.name != source.name
            || db.dateUpload != source.dateUpload
            || db.chapterNumber != source.chapterNumber
            || db.sourceOrder != source.sourceOrder
            || db.memo != source.memo
    }
}
