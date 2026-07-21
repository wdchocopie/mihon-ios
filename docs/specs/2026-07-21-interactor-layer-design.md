# Interactor Layer — Design Spec

**Status:** Implemented (chapter-sync core + navigation); rest deferred
**Objective:** Port Mihon's application-logic interactors — the use-cases the
ViewModels call — into `MihonCore/Interactor/`, focusing on the ones with **real,
bit-exact logic** rather than the thin repository-delegation ceremony.
**Android source:** `app/.../domain/chapter/interactor/SyncChaptersWithSource.kt`,
`domain/.../history/interactor/GetNextChapters.kt`, `data/.../ChapterSanitizer.kt`.

## Design — pure cores, injected side effects

Mihon's interactors interleave logic with I/O (repo writes, download-file rename,
`HttpSource.prepareNewChapter`, preference reads). This port extracts the **pure
computation** as a testable function and leaves side effects to the caller — so
the logic runs and tests on the free Windows loop with **no repository fakes**.

- **`ChapterSync`** — the crown jewel: the merge that reconciles a source's
  chapter list against the DB. It decides add/update/delete AND inherits read &
  bookmark state from deleted chapters onto re-added ones of the same chapter
  number (so a re-uploaded chapter a user already read stays read — the whole
  reason this logic exists). Also: dedup by URL, chapter-number recognition,
  descending `dateFetch` assignment, `markDuplicateAsRead`, and reusing a deleted
  chapter's fetch date to avoid polluting the Updates tab. Side effects
  (`prepareNewChapter`, download rename, the repo writes, fetch-interval update)
  are the caller's; `ShouldUpdateDbChapter` is injected.
- **`GetNextChapters`** — "what to read next": sorts ascending-reading-order
  (descending `sourceOrder` — the SOURCE inversion), filters unread, and handles
  the from-a-chapter "is the current one finished?" case.
- **`ChapterSanitizer`** + `Chapter.copyFrom(sChapter:)` — name cleanup and the
  source→domain chapter mapping the sync depends on.

## Verification

12 tests, incl. the read/bookmark-inheritance path, `markDuplicateAsRead`,
dedup, delete, and the navigation edge cases. Two test-authoring bugs surfaced
real Mihon semantics and were corrected: the SOURCE-order inversion (reading
order = descending `sourceOrder`) and `ShouldUpdateDbChapter`'s unguarded
`dateUpload` comparison.

## Deferred

The download-file rename and `HttpSource.prepareNewChapter` (source-runtime /
download subsystem — ADR-0/Mac gated); the thin delegation interactors
(GetManga/GetChapter/GetCategories — pure ceremony); category-management
interactors (need a `CategoryUpdate`/preference-store pass); the repository-bound
interactor wrappers (need the GRDB tier or in-memory fakes).
