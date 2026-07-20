---
name: codebase-review
description: "Phased audit of an entire codebase or a large portion of it. Triggers on 'review the codebase', 'audit the project', 'full code review of this repo', 'check the architecture', 'is this project in good shape?', 'review our whole backend', 'health-check this app'. Explores the code thoroughly (via the deep-exploration skill, fanning out across the repo), researches the current state of its key technologies online so feedback reflects today's best practices, cross-references code against that research, then delivers a prioritized review — executive summary, verdict, severity-tiered findings, doc follow-ups. NOT for a single file, function, or diff (use code-quality-review); NOT for hunting bugs in a PR diff (use the native /code-review command)."
version: 1.0.0
---

# Codebase Review (whole-system audit)

A full-codebase audit grounds its feedback in **two** things: the actual code *and* the
current state of the technologies it uses. The failure mode to avoid is reviewing a large
repo from a quick skim plus stale training knowledge. This workflow forces you to explore
broadly, refresh what "current best practice" means, and only then judge.

## Scope check first

This is the right tool when the target is **the whole codebase or a large area** (a whole
service, the entire frontend, etc.). If the user actually handed you a single file, a
function, or a diff, use **`code-quality-review`** instead — it's lighter and bounded. If
they want bugs hunted in a PR diff and posted as comments, that's the native
**`/code-review`** command.

## Phase 1 — Explore and understand (delegate the heavy lifting)

Build a real mental model before forming any opinion. Because a codebase audit spans
multiple modules by definition, **use the `deep-exploration` skill** here rather than
reading file-by-file yourself: it takes a bird's-eye pass, divides the repo into sections,
and dispatches read-only Explore subagents in parallel to investigate each section, then
synthesizes their findings. That fan-out is exactly what a thorough audit needs.

Direct that exploration to surface, at minimum:
1. **Stack & versions** — read `package.json` / `pubspec.yaml` / `requirements.txt` /
   `go.mod` / `Cargo.toml` or equivalent. Identify frameworks, libraries, and versions.
2. **Architecture** — directory structure, entry points, routing, state management, data
   layer, configuration (CI, Docker, infra-as-code).
3. **Core logic & patterns** — the business logic, data models, custom abstractions, and
   the architectural style the team chose (MVC, clean architecture, feature-first, …).
4. **A running list of observations** — technologies/versions, patterns, areas that look
   strong, areas that smell off. Observe; don't judge yet.

Keep the list of "technologies central to the architecture" — you'll research those next.

## Phase 2 — Research current best practices

Now that you know what the project uses, get up to date. Libraries move fast; a pattern
that was idiomatic two years ago can be an anti-pattern today, and your training data may
lag.

For each **central** technology (framework, language runtime, state management, DB/ORM,
auth, and any library core to the architecture — not every utility), use web search and
documentation tools (the **Context7 MCP** for library docs) to check:
- Latest stable version — is the project significantly behind?
- Have APIs the project uses been deprecated or replaced?
- Are there new recommended patterns that differ from what the project does?
- Any known security advisories for the versions in use?

Save these findings — you'll cite them in the review.

## Phase 3 — Deep dive (cross-reference)

With fresh research in hand, go back in with sharper eyes:
1. **Cross-reference** code against the best practices you just confirmed — deprecated API
   usage, outdated patterns, missed newer/better approaches.
2. **Trace critical paths** end-to-end (auth flow, main CRUD operations, data sync). This
   is where architectural issues surface. Spin up a focused follow-up Explore agent on any
   path that turns out tangled.
3. **Check for gaps** — error handling, logging, test coverage, environment config,
   security boundaries.

## Phase 4 — Deliver the review

Use the **same output format as `code-quality-review`** (executive summary → verdict →
severity-tiered findings → what's working → documentation), scaled up to the whole system.
Read `../code-quality-review/references/*.md` for the standards behind each finding
(architecture, security, performance, testing, devops, documentation).

For a codebase audit specifically:
1. **Executive summary** — what the project is, the tech stack, the architectural
   approach, and the overall health assessment. Then the **Verdict** (✅ good shape /
   ⚠️ needs attention / 🚫 critical issues).
2. **Organize findings by impact and theme** — group by architecture, security,
   performance, dependencies, testing, etc., each with 🔴/🟡/🔵 tiers. Lead with blockers.
3. **Cite your research** — "As of [framework] v[X], the recommended approach is…" or
   "This API was deprecated in v[X] in favor of…". This is what separates a grounded audit
   from a guess.
4. **Be actionable** — every finding says what to do, not just what's wrong.
5. **Acknowledge what's good** — call out solid decisions so the team knows what to preserve.

## Phase 5 — Documentation review

After the audit, check whether docs need to catch up. Scan `docs/`, `README.md`, ADRs,
data dictionaries, and workflow/user-journey docs. For each significant change-area the
audit touched, suggest a **specific** update (name the file and section) or a new doc only
when warranted. Follow `../code-quality-review/references/documentation.md`. Present it as
the `📝 Documentation` section of the review.

## When done
End with **"What you can do next:"** — 2–4 concrete, high-impact follow-ups (e.g. "Fix the
2 dependency CVEs first — migration guides are straightforward," "Add integration tests for
the auth flow — highest-risk untested path," "Run `/code-review` on the next PR to catch
regressions at the diff level").
