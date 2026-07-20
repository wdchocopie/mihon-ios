---
name: codebase-wide-change
description: "Apply a change consistently ACROSS an entire codebase with zero missed files in one pass. Triggers on 'rename X everywhere', 'refactor all Y to Z', 'update this pattern across the app', 'change every usage of', 'migrate all callers to', 'replace this API throughout', 'update all imports of'. Casts a wide net for every affected file (source, tests, types, configs, docs, dynamic references), changes them systematically while tracing cascading effects, then re-searches to verify nothing was missed. Uses the deep-exploration skill to build the inventory in parallel for large or multi-module changes. NOT for a single-file edit (just edit it); NOT a code review (use code-quality-review or codebase-review)."
version: 1.0.0
---

# Exhaustive Codebase-Wide Change

When a change must land **everywhere** — a rename, a pattern migration, an API
replacement — the danger isn't making the edit, it's *missing* one. A half-applied
rename leaves the codebase broken in ways that compile-and-pray won't always catch. The
goal of this workflow is **zero missed files in a single pass**: the user should never
need to say "check again, more thoroughly."

Only reach for this when the change genuinely spans the codebase. A single-file edit
doesn't need this ceremony — just make it.

## Step 1 — Inventory ALL affected files (before editing anything)

Cast a wide net. Use Glob and Grep extensively to find **every** file that could be
affected — do not start editing until the list is complete.

Search for:
- The exact string/pattern being changed
- **Variations** — different casing, partial matches, abbreviations, pluralizations
- Related **imports, exports, and re-exports**
- **Type references**, interface usages, generic parameters
- **Test files** that reference the changed code
- **Config, seed, and migration files**
- **Documentation and comments** that reference the old pattern
- **Indirect/dynamic references** — string literals, computed property names, reflection,
  serialized names, i18n keys

Then:
- **Build a complete file list** — write it down.
- **Categorize by type** — source / tests / types / configs / docs. Grouping stops you
  from forgetting an entire category (tests and docs are the usual casualties).

**For a large codebase or a change spanning many modules, use the `deep-exploration`
skill** to build this inventory: it divides the repo into sections and runs Explore
subagents in parallel, each hunting its section for every variant of the pattern. That
parallel sweep is far more reliable than one sequential grep pass on a big repo. Give each
Explore agent the exact strings/variants to hunt and ask it to return every hit as
`path:line`.

## Step 2 — Make the changes systematically

1. **Work the list file by file** — check each off. Don't skip any.
2. **Read the relevant section first** for context before editing each file.
3. **Trace cascading effects** — when a change in file A forces a change in file B (a
   renamed export, a changed signature), add B to the list if it's not already there.
   Keep the list live; new files surface as you go.

## Step 3 — Verify exhaustively (MANDATORY)

After all changes, run a verification pass — this is the step that earns the "single pass"
promise:
1. **Re-run the Step 1 searches** — Glob/Grep for the old pattern again. Confirm **zero**
   remaining instances (or consciously justify each survivor).
2. **Type-check / compile** if the stack supports it, to catch broken references.
3. **Search for indirect references** again — dynamic/string/computed forms your first
   pass may have missed.
4. **Verify imports/exports** — no file still imports the old name or references the old
   pattern.

If you find missed files during verification, **fix them immediately** — never report them
as "remaining items for the user to handle."

## Step 4 — Report completeness

End with a verification summary:
```
## Verification
- Files modified: [count]
- Grep for old pattern: [0 results / or list remaining + why]
- Type check: [pass/fail/n.a.]
- Confidence: [complete / needs manual review for X reason]
```

## Key rules
- **Never stop at "I think that's all"** — always verify with a final search pass.
- **Never assume a directory is irrelevant** — search everywhere: tests, scripts, seeds, configs, docs.
- **When in doubt, search more broadly** — a false positive is cheap to dismiss; a missed file ships a bug.
- **Migration safety** — if the change breaks existing data, APIs, or persisted state, surface a migration plan *before* proceeding, not after.
- **Touch only what the change requires.** As you sweep the codebase you'll pass uncommitted or unexpected edits that have nothing to do with your rename/migration — they may be the user's own work-in-progress or another agent's changes. Apply *your* change to each file and leave everything else exactly as you found it. Don't revert, undo, "tidy," or overwrite unrelated modifications as a side effect, and don't `git checkout`/`reset` to get a "clean" starting point. If pre-existing changes genuinely block the migration or look wrong, surface them and ask — revert only when the user explicitly asks.

## When done
End with **"What you can do next:"** — e.g. "Run the test suite to confirm nothing broke,"
"Run `/code-review` on the diff," "Update the changelog/docs for the rename."
