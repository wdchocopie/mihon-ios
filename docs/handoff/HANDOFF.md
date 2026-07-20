# Handoff — 2026-07-19

**Session:** Read the Mihon source and the Keiyoushi extension catalog, then
produce the Android→iOS conversion plan via parallel fan-out.
**Branch / worktree:** none — folder is still not a git repository.

## Done this session

- **Scaffolded the workspace** (prior session): `CLAUDE.md` → `AGENTS.md`, 26
  skills in `.claude/skills/`, `docs/` system with templates. See git-less
  `docs/` tree.
- **Fetched both sources:** Mihon (`github.com/mihonapp/mihon`, 905 Kotlin
  files / 81,258 lines / 15 Gradle modules) and the Keiyoushi index
  (1,367 extensions → 2,016 source entries). Later also cloned
  `keiyoushi/extensions-source` to measure themes.
- **Wrote a context pack** at `.claude/plans/mihon-ios-port-context.md` — the
  verbatim `Source` protocol, the real `mangas`/`chapters` DDL including the
  5 triggers, module map, and measured scale. Every agent read this instead of
  re-deriving from raw sources.
- **Ran a 9-agent workflow** (6 analysis lanes + 3 adversarial verifiers), Opus
  at high effort, per the `parallel-execution` skill's distribute-then-dispatch
  procedure. 745k tokens, ~12 min, 0 errors.
- **Measured the theme lever myself** — the number all three verifiers flagged
  as unmeasured and highest-leverage: **53.8% of extensions (736/1367) are thin
  theme subclasses.** `madara` = 295, `mangathemesia` = 145, top 10 = 41.7%.
  This clears the >50% bar that makes a theme-first catalog strategy correct.
- **Wrote `docs/plans/2026-07-19-mihon-ios-port.md`** — the master plan: 5 waves,
  effort table, 9-item blocker risk register, 5 gating ADRs, explicit
  "what I did not verify" section.
- Updated `docs/plans/README.md`, `docs/decisions/README.md` (pending-ADR
  table), and corrected `ANDROID_TO_IOS_PLAYBOOK.md` where yesterday's
  assumptions are now measured.

## In flight (half-done)

- Nothing mid-edit. The plan is complete but **proposed, not approved** — per
  the `AGENTS.md` plan gate it needs sign-off before any code.

## Next up

1. **Verify the Paperback question** (see landmines) — it decides ADR-0.
2. Get user sign-off on ADR-0 distribution, then write ADRs 0–4.
3. `git init` + commit the scaffold and plan.
4. Add the Mihon source under `android/` as read-only reference.
5. Submit the MyAnimeList API application — human-reviewed, calendar time
   starts immediately and cannot be parallelized.
6. Run Wave 0's two spikes (`.tachibk` wire format; bridged-DOM vs Cheerio
   benchmark) and the three timed source ports.

## Landmines / gotchas

- **UNRESOLVED CONFLICT, needs a human call.** Lane 6 says an App Store build
  must have a *statically compiled* source set (2.5.2/3.3.2). The policy
  verifier says Guideline 4.7 affirmatively permits JS plug-ins and that
  **Paperback (JS-based) is on the App Store today while Aidoku (WASM) is not**
  — inverting Lane 6's evidence. The load-bearing unverified fact: whether
  Paperback's *App Store binary* can add arbitrary third-party repos, or only
  its sideloaded build can. **I did not verify this.** ~30 minutes of checking
  decides months of architecture.
- **All 3 adversarial lenses returned holdsUp=false** — but each *kept* the
  JavaScriptCore choice while refuting the reasoning around it. Read their
  corrections before relitigating the runtime: the objections are about the
  ecosystem metric, the Cloudflare mechanism, and the policy basis, not the
  runtime.
- **Cloudflare is commonly misdiagnosed as JA3 fingerprinting.** The real
  mechanism is cookie-store unification (`AndroidCookieJar.kt:10` backs OkHttp's
  jar with Android's `CookieManager`). iOS has no unified store. Budget explicit
  bidirectional WKHTTPCookieStore ↔ HTTPCookieStorage bridging.
- **`JavaScriptEngine.kt:11-25` exposes `evaluate()` to extensions** — sources
  eval *site-supplied* JS. On iOS that would inherit the whole host bridge. A
  second bridge-free `JSContext` is a v1 requirement, not hardening.
- **Index entries ≠ reach.** MangaDex's 61 entries are 61 language variants of
  one site. 94.5% of packages are single-source. Count websites.
- The `extensions-source` repo uses a **new Gradle DSL** (`theme = "madara"`,
  not the old `themePkg = '...'`). An old-syntax grep returns 0 and looks like
  a real answer — it isn't.
- Cloning `global.dev` on Windows needs `core.longpaths=true`.

## Open questions (blocking)

- **ADR-0 distribution** — App Store + sideload two-track, or sideload-only?
  Blocks the runtime design and therefore every other lane.
- **Which Mihon/Tachiyomi tree is the port target?** This session used Mihon
  (the maintained fork) — confirm that's intended.
- Is external contributor inflow expected? The plan assumes **zero**. If there
  is no bootstrap plan, v1 should be 10–15 sources, not ~30.
- Mac access: Mac mini (~$600) or cloud Mac (~$60/mo)? Not optional before
  Wave 3.

## Pick up from

- `docs/plans/2026-07-19-mihon-ios-port.md` — the master plan; start at
  "Three decisions that gate everything".
- `.claude/plans/mihon-ios-port-context.md` — distilled source facts.
- Full 9-agent output (331 KB):
  `C:\Users\WDCHOC~1\AppData\Local\Temp\claude\C--Users-WDchocopie-Downloads-Tachiyomi-beta\92763d0f-1b81-433c-a2e7-1a8255cf779d\tasks\w1h0p3hgp.output`
  (results nested under `.result`, not top level).
- Workflow script (re-runnable / resumable):
  `...\workflows\scripts\mihon-ios-port-plan-wf_67b79504-804.js`, run ID
  `wf_67b79504-804`.
- Command to resume: none (no build yet) — start with `git init` in
  `C:\Users\WDchocopie\Downloads\Tachiyomi_beta`.
