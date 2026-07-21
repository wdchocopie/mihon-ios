# Source / Catalogue API — Design Spec

**Status:** Implemented (contract models; concrete runtime is ADR-0/ADR-1-gated)
**Objective:** Port Mihon's `source-api` extension contract — the `Filter`
hierarchy and the source capability protocols — into `MihonCore`. This is the
foundation the browse/catalog/search half of the app stands on.
**Android source:** `source-api/.../model/Filter.kt`, `FilterList.kt`, and the
`Source*`/`*Source` protocol files.

## Why now, and why it's unblocked

Recreating Mihon means porting its spine layer by layer. The catalogue contract
is the next foundation: browse, global search, and "add to library" all consume
`Filter`/`FilterList` and the source protocols. Crucially, the **contract is
platform-agnostic and NOT ADR-0-blocked** — only the *concrete* source runtime
(the JavaScriptCore engine that executes real sources, ADR-1) is gated. So the
models and protocols build and test on the free Windows loop today.

## Design

- **`Filter`** — a class hierarchy (not an enum), faithful to Kotlin's
  `Filter<T>` with **mutable `state`**: the UI edits filters in place and hands
  them back to `getSearchManga`. Subtypes: `Header`, `Separator`, `Select<V>`
  (index), `Text`, `CheckBox`, `TriState` (ignore=0/include=1/exclude=2),
  `Group<V>`, `Sort` (index + ascending). `@unchecked Sendable` — mutation is
  single-threaded within a source's own call flow.
- **`FilterList`** — a `RandomAccessCollection` wrapping `[Filter]`. Kotlin's
  deliberate `equals == false` (a Compose recomposition hack) is intentionally
  not reproduced.
- **Capability protocols** — `CatalogueSource` (requires `lang`), `SourceFactory`
  (`createSources`), `UnmeteredSource` (marker), `ConfigurableSource`
  (per-source `preferenceKey = "source_<id>"`; the `PreferenceScreen` UI is
  deferred to the runtime), `ResolvableSource` + `UriType` (deep-link resolution).

## Decisions settled here

- **Class hierarchy over value types for `Filter`**, to preserve Kotlin's
  mutable-state contract that the search UI depends on.
- **Rx bridge dropped** — only the modern async `Source` API is ported.

## Deferred

- `ConfigurableSource.setupPreferenceScreen` takes `Any` until the
  `PreferenceScreen`-equivalent lands with the runtime (ADR-1).
- `HttpSource`/`ParsedHttpSource` concrete bases (networking + Jsoup-equivalent)
  belong to the source runtime, ADR-0-gated.
