# Context Pack — Mihon → iOS Port Analysis

Shared context for all analysis agents. **Read this instead of re-deriving from
the raw Kotlin sources.** Everything here was extracted from the real Mihon
source; verbatim code below is copied exactly, not paraphrased.

## Where things are

- **Mihon Android source (read-only):**
  `C:\Users\WDCHOC~1\AppData\Local\Temp\claude\C--Users-WDchocopie-Downloads-Tachiyomi-beta\92763d0f-1b81-433c-a2e7-1a8255cf779d\scratchpad\mihon`
- **Keiyoushi extension index (JSON):** same scratchpad, `keiyoushi-index.json`
- **Target project:** `C:\Users\WDchocopie\Downloads\Tachiyomi_beta`
  (currently docs + skills only; no iOS code yet)

## Scale (measured, not estimated)

- **905 Kotlin files, 81,258 lines** across 15 Gradle modules.
- **1,367 extensions** in the Keiyoushi repo. Language spread: en 416,
  all 126, ja 112, pt-BR 110, es 109, id 86, tr 78, vi 70, fr 55, ar 52,
  zh 46, th 36.

## Gradle module map

```
:app                 UI + ViewModels (Compose, Voyager nav)
:core:common         utilities, coroutine helpers
:core:archive        CBZ/ZIP/RAR archive reading (libarchive)
:core:viewmodel      VM base
:core-metadata       ComicInfo / metadata parsing
:data                SQLDelight DB, repositories impl
:domain              entities, interactors, repository interfaces
:i18n                Moko-resources localized strings
:presentation-core   shared Compose components
:presentation-widget Android home-screen widgets (NO iOS equivalent — WidgetKit rewrite)
:source-api          the extension contract (see below)
:source-local        local files as a source
:telemetry           analytics/crash
```

## THE CRITICAL CONTRACT — `:source-api`

Every extension implements this. It is the hinge of the whole port: on
Android these are separate APKs loaded via `DexClassLoader`, which iOS
forbids. Verbatim from
`source-api/src/commonMain/kotlin/eu/kanade/tachiyomi/source/Source.kt`:

```kotlin
interface Source {
    val id: Long                  // unique, stable — matches "id" in the Keiyoushi index
    val name: String
    val lang: String get() = ""
    val supportsLatest: Boolean

    fun getFilterList(): FilterList = FilterList()

    suspend fun getPopularManga(page: Int): MangasPage
    suspend fun getLatestUpdates(page: Int): MangasPage
    suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage

    suspend fun getMangaUpdate(
        manga: SManga,
        chapters: List<SChapter>,
        fetchDetails: Boolean,
        fetchChapters: Boolean,
    ): SMangaUpdate

    suspend fun getPageList(chapter: SChapter): List<Page>
    // + deprecated Rx Observable variants (fetchMangaDetails/fetchChapterList/fetchPageList)
    // which MOST published extensions still implement — CatalogueSource bridges
    // them to the suspend API via awaitSingle().
}
```

Model shapes (verbatim fields):

```kotlin
interface SManga {
    var url: String; var title: String; var thumbnail_url: String?
    var artist: String?; var author: String?; var status: Int
    var description: String?; var genre: String?
    var update_strategy: UpdateStrategy      // ALWAYS_UPDATE | ONLY_FETCH_ONCE
    var initialized: Boolean
    var memo: JsonObject                     // source-specific metadata, since tachiyomix 1.6
    // status constants: UNKNOWN 0, ONGOING 1, COMPLETED 2, LICENSED 3,
    //                   PUBLISHING_FINISHED 4, CANCELLED 5, ON_HIATUS 6
}

interface SChapter {
    var url: String; var name: String; var chapter_number: Float
    var scanlator: String?; var date_upload: Long; var memo: JsonObject
}

open class Page(index: Int, url: String = "", imageUrl: String? = null, uri: Uri?)
    : ProgressListener {
    // status: State = Queue | LoadPage | DownloadImage | Ready | Error(Throwable)
    // exposes statusFlow / progressFlow (MutableStateFlow)
}
```

Sub-interfaces: `CatalogueSource` (adds `lang`, bridges deprecated Rx →
suspend), `HttpSource`, `ParsedHttpSource` (Jsoup-based HTML scraping —
**this is what most extensions extend**), `ConfigurableSource` (source
settings screen), `ResolvableSource`, `UnmeteredSource`, `SourceFactory`.

**Extensions depend on Jsoup (HTML parsing), OkHttp, and Rx.** Any iOS
source runtime must supply equivalents of all three or the ported sources
won't work.

## Keiyoushi index entry shape (verbatim from the downloaded JSON)

```json
{
  "name": "Tachiyomi: AHottie",
  "pkg": "eu.kanade.tachiyomi.extension.all.ahottie",
  "apk": "tachiyomi-all.ahottie-v1.4.3.apk",
  "lang": "all",
  "code": 3,
  "version": "1.4.3",
  "nsfw": 1,
  "sources": [
    { "name": "AHottie", "lang": "all",
      "id": "6289731484943315811", "baseUrl": "https://ahottie.top" }
  ]
}
```

Note: the index points at **APK artifacts**. There is no JS/WASM build of
these sources — an iOS port cannot consume this repo directly. The `id`
values matter: they are the same source IDs stored in the `mangas.source`
DB column and inside backups, so preserving them is what makes an imported
library resolve to the right source.

## Database schema (SQLDelight → must map to iOS persistence)

Tables: `mangas`, `chapters`, `categories`, `mangas_categories`, `history`,
`manga_sync` (trackers), `sources`, `excluded_scanlators`, `extension_store`.
Views: `libraryView`, `historyView`, `updatesView`. **13 migrations**
(`1.sqm`–`13.sqm`) — the current schema version is what a backup importer
must target.

Verbatim `mangas` table (the central entity):

```sql
CREATE TABLE mangas(
    _id INTEGER NOT NULL PRIMARY KEY,
    source INTEGER NOT NULL,
    url TEXT NOT NULL,
    artist TEXT, author TEXT, description TEXT,
    genre TEXT AS List<String>,
    title TEXT NOT NULL,
    status INTEGER NOT NULL,
    thumbnail_url TEXT,
    favorite INTEGER AS Boolean NOT NULL,
    last_update INTEGER, next_update INTEGER,
    initialized INTEGER AS Boolean NOT NULL,
    viewer INTEGER NOT NULL,
    chapter_flags INTEGER NOT NULL,
    cover_last_modified INTEGER NOT NULL,
    date_added INTEGER NOT NULL,
    update_strategy INTEGER AS UpdateStrategy NOT NULL DEFAULT 0,
    calculate_interval INTEGER DEFAULT 0 NOT NULL,
    last_modified_at INTEGER NOT NULL DEFAULT 0,
    favorite_modified_at INTEGER,
    version INTEGER NOT NULL DEFAULT 0,
    is_syncing INTEGER NOT NULL DEFAULT 0,
    notes TEXT NOT NULL DEFAULT "",
    memo BLOB AS JsonObject NOT NULL DEFAULT '{}'
);
```

```sql
CREATE TABLE chapters(
    _id INTEGER NOT NULL PRIMARY KEY,
    manga_id INTEGER NOT NULL,
    url TEXT NOT NULL, name TEXT NOT NULL, scanlator TEXT,
    read INTEGER AS Boolean NOT NULL,
    bookmark INTEGER AS Boolean NOT NULL,
    last_page_read INTEGER NOT NULL,
    chapter_number REAL NOT NULL,
    source_order INTEGER NOT NULL,
    date_fetch INTEGER NOT NULL, date_upload INTEGER NOT NULL,
    last_modified_at INTEGER NOT NULL DEFAULT 0,
    version INTEGER NOT NULL DEFAULT 0,
    is_syncing INTEGER NOT NULL DEFAULT 0,
    memo BLOB AS JsonObject NOT NULL DEFAULT '{}',
    FOREIGN KEY(manga_id) REFERENCES mangas (_id) ON DELETE CASCADE
);
```

**Non-obvious DB behavior that must be reproduced, not just the columns:**
SQLite **triggers** maintain `last_modified_at`, `favorite_modified_at`, and
the `version` counters used for sync conflict resolution. `version`
increments only when `is_syncing = 0` and specific fields change. A naive
port that drops the triggers silently breaks sync/backup semantics.

## UI surface inventory

`app/src/main/java/eu/kanade/presentation/`: browse, category, components,
crash, history, library, manga, more, reader, theme, track, updates, util,
webview.

`app/src/main/java/eu/kanade/tachiyomi/ui/`: base, browse, category,
deeplink, download, history, home, library, main, manga, more, reader,
security, setting, stats, updates, webview.

`domain/.../tachiyomi/domain/`: backup, category, chapter, download,
history, library, manga, release, source, storage, track, updates.

## Standing project rules (from AGENTS.md / the playbook)

- Docs-first: spec → plan → build. Plan gate before any code.
- The Android source is the behavioral ground truth — cite `path:line`.
- Idiomatic Swift, not transliterated Kotlin. Behavior parity, not
  line-by-line parity.
- Windows dev machine: Swift can be authored, but **builds/simulator need
  macOS + Xcode**.
- Prior art to study: **Aidoku** (Swift, WASM sources), **Suwatte**,
  **Paperback** (JS sources via JavaScriptCore).
