# `.tachibk` Backup Decoder — Design Spec (Wave-0 Spike)

**Status:** Implemented (spike — decode path + logical round-trip; real-file
validation pending a user-provided backup)
**Objective:** Answer the Wave-0 spike question (plan R3): reverse-engineer the
`.tachibk` wire format from the Mihon source and prove Swift can decode it —
and decide whether swift-protobuf suffices or a hand-rolled reader is needed.
**Android source (the spec):** `app/.../data/backup/models/*.kt` +
`BackupDecoder.kt` in the Mihon tree.
**Hard invariants:** exact field numbers, exact defaults (a wrong default
silently corrupts a user's library — see `favorite` below), source-ID fidelity
(R4).

## Finding: it is gzipped kotlinx-serialization ProtoBuf

`BackupDecoder.kt` peeks the first 2 bytes:
- `0x1f8b` → gzip; gunzip then protobuf-decode.
- `0x7b7d` / `0x7b22` / `0x7b0a` (`{}`, `{"`, `{\n`) → legacy JSON backup → reject.
- else → treat as raw (un-gzipped) protobuf.

Then `ProtoBuf.decodeFromByteArray(Backup.serializer(), bytes)`. So the payload
is **kotlinx-serialization's ProtoBuf dialect**, not a `.proto`-generated format.

## Decision: hand-rolled wire reader, NOT swift-protobuf

swift-protobuf would require a hand-authored `.proto` AND still could not match
three kotlinx conventions cleanly. A ~200-line dependency-free wire reader gives
full control and stays platform-agnostic (testable on Windows). The three
conventions that force this:

1. **Non-packed repeated scalars.** kotlinx encodes `List<T>` as repeated
   *non-packed* fields (each element separately tagged) unless `@ProtoPacked` —
   which Mihon never uses. swift-protobuf proto3 emits *packed* scalar repeats.
   So `genre: List<String>` (field 7) and `categories: List<Long>` (field 17)
   are a sequence of individually-tagged values.
2. **Default omission with non-trivial defaults.** Absent field ⇒ the Kotlin
   default. Most are the obvious zero/empty, but **`BackupManga.favorite`
   defaults to `true`** — a decoder that defaults booleans to `false` silently
   un-favorites every restored manga. Others: `title=""`, `notes=""`,
   `updateStrategy=ALWAYS_UPDATE(0)`, `genre=[]`.
3. **Polymorphic `PreferenceValue`** (see below) — no swift-protobuf analogue.

## Derived schema (from the `@ProtoNumber` annotations)

Wire types: varint=0 (Int/Long/Bool/enum), fixed64=1, len-delim=2
(String/bytes/message/each-repeated-element), fixed32=5 (Float).

### `Backup` (root)
| # | field | type | note |
|---|---|---|---|
| 1 | backupManga | repeated BackupManga | |
| 2 | backupCategories | repeated BackupCategory | |
| — | 100 | *skipped* | legacy broken sources (non-compliant #) |
| 101 | backupSources | repeated BackupSource | |
| 104 | backupPreferences | repeated BackupPreference | app prefs |
| 105 | backupSourcePreferences | repeated BackupSourcePreferences | |
| 106 | backupExtensionStores | repeated BackupExtensionStore | |

### `BackupManga` — field numbers with legacy gaps
1 source:Long · 2 url:String · 3 title:String="" · 4 artist:String? ·
5 author:String? · 6 description:String? · 7 genre:repeated String ·
8 status:Int=0 · 9 thumbnailUrl:String? · 13 dateAdded:Long=0 ·
14 viewer:Int=0 · 16 chapters:repeated BackupChapter · 17 categories:repeated
Long · 18 tracking:repeated BackupTracking · **100 favorite:Bool=true** ·
101 chapterFlags:Int=0 · 103 viewer_flags:Int?=null · 104 history:repeated
BackupHistory · 105 updateStrategy:enum=ALWAYS_UPDATE(0) · 106 lastModifiedAt:Long
· 107 favoriteModifiedAt:Long? · 108 excludedScanlators:repeated String ·
109 version:Long · 110 notes:String="" · 111 initialized:Bool=false ·
112 memo:bytes (default = `{}` JSON bytes).
Restore uses `viewer_flags ?: viewer` (MangaRestorer parity).
Gaps 10/11/12/15 are 1.x-only, never emitted by Mihon.

### `BackupChapter`
1 url · 2 name · 3 scanlator:String? · 4 read:Bool=false · 5 bookmark:Bool=false
· 6 lastPageRead:Long=0 · 7 dateFetch:Long=0 · 8 dateUpload:Long=0 ·
9 chapterNumber:Float=0 (fixed32) · 10 sourceOrder:Long=0 · 11 lastModifiedAt:Long
· 12 version:Long=0 · 13 memo:bytes.

### `BackupCategory`  1 name · 2 order:Long=0 · 3 id:Long=0 · 100 flags:Long=0
### `BackupSource`    1 name:String="" · 2 sourceId:Long
### `BackupHistory`   1 url · 2 lastRead:Long · 3 readDuration:Long=0
### `BackupTracking`  1 syncId:Int · 2 libraryId:Long · 3 mediaIdInt:Int=0 (deprecated) · 4 trackingUrl="" · 5 title="" · 6 lastChapterRead:Float=0 · 7 totalChapters:Int=0 · 8 score:Float=0 · 9 status:Int=0 · 10 startedReadingDate:Long=0 · 11 finishedReadingDate:Long=0 · 12 private:Bool=false · 100 mediaId:Long=0
### `BackupExtensionStore` 1 indexUrl · 2 name · 3 badgeLabel:String? · 4 contactWebsite · 5 signingKey · 6 contactDiscord:String? · 7 isLegacy:Bool? · 8 extensionListUrl:String?

Landmine (restore, from MangaRestorer): tracking `remoteId` =
`mediaIdInt != 0 ? mediaIdInt : mediaId` — the burned field-3/field-100 split.

## The polymorphic wart: `PreferenceValue`

`BackupPreference = { 1:key:String, 2:value:PreferenceValue }` where
`PreferenceValue` is a **sealed class** with 6 subtypes (Int/Long/Float/String/
Boolean/StringSet). kotlinx encodes a polymorphic value as a 2-field wrapper
message: **field 1 = type discriminator (String = the subtype's fully-qualified
serial name, e.g. `eu.kanade.tachiyomi.data.backup.models.IntPreferenceValue`),
field 2 = the nested payload** (the subtype, whose single unannotated `value`
property is implicit field 1). swift-protobuf cannot express this. It is
**deferred in this spike** — characterized here, decoded later with a hand-written
polymorphic reader. Preferences are not on the library-migration critical path.

## Scope of the spike implementation

- IN: wire reader/writer, and decode of `Backup → manga/chapters/categories/
  sources/history/tracking`. Logical round-trip test (writer↔reader).
- DEFERRED: gzip inflate (outer wrapper — magic detection implemented, inflate
  is a separable known step), `PreferenceValue` polymorphic decode,
  `BackupExtensionStore`, byte-exact ENCODE parity with kotlinx (omit-default
  behavior) — needed for export, not for the spike's decode question.

## Pending validation (needs the user)

The schema is derived from source and proven self-consistent by round-trip, but
**not yet validated against a real `.tachibk`**. To close it: export a backup
from Mihon (Settings → Data and storage → Create backup), drop the file in, and
a decode test asserts the manga/chapter counts and known field values. Until
then R3 is "characterized", not "closed".

---
Pairs with the master plan Wave-0 spike item; no separate plan doc (this spike
IS the investigation the plan called for).
