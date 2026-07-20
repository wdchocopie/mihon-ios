# Decisions (ADRs)

One file per durable decision: `NNNN-short-slug.md`. Use `../templates/decision.md`.

Append-only. Never edit a decided record's substance — if it turns out wrong,
write a new ADR and mark the old one `Superseded by NNNN`.

Numbering is sequential and never reused.

| # | Decision | Status |
|---|----------|--------|
| — | (none written yet) | |

## Pending — required before any code

Derived from the [master conversion plan](../plans/2026-07-19-mihon-ios-port.md).
ADR-0 gates all the others: it determines what the source runtime is even
allowed to be, so deciding it late invalidates work across every lane.

| # | Decision | Recommendation | Blocked on |
|---|----------|----------------|------------|
| 0 | Distribution route | Two builds: App Store (local/self-hosted reader, zero aggregator sources) + sideload (full dynamic catalog). Never one binary with a hidden toggle. | Verifying whether Paperback's App Store build can add arbitrary repos |
| 1 | Source/extension runtime | JavaScriptCore + Cheerio-equivalent DOM. Survived 3 adversarial lenses; Guideline 4.7 names JS and names nothing else. | ADR-0 |
| 2 | Persistence | GRDB.swift. SwiftData cannot express the 5 triggers, 3 views, CTE query, or trigger-aware observation. | nothing — ready to write |
| 3 | Minimum iOS version | iOS 17.0 (`@Observable`, scroll APIs, ContentUnavailableView) | nothing |
| 4 | DI replacing Injekt | Hand-rolled `AppEnvironment`; Mihon's whole graph is 435 lines | nothing |

When each is settled, write it as `NNNN-slug.md` from `../templates/decision.md`
and move it into the table above.
