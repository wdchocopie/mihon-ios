---
name: spec-gen
description: >-
  Generate business specification documents (Features + Business Logic) from a codebase or
  prototype. Use when the user wants to write or update specs, feature documentation, or business
  rules derived from source code — triggered by "/spec-gen", "generate spec", "write spec from
  code", "document this module", "sinh spec", "viết đặc tả". Supports --research to study the
  business domain and legacy systems to fill gaps the code alone doesn't reveal. Produces
  business-only specs (no implementation details); technical traceability goes to a separate
  _trace file. NOT for API reference docs or code comments.
version: 1.0.0
---

# Generate specs from a codebase/prototype

Generate (or update) specification documents for a module: one **Features** file (screens &
interactions — "what's on this screen, what do I click?") and one **Business Logic** file
(business rules & formulas — "how does the system compute this?") — grounded 100% in source
code. This skill is generic and works on any project.

## Step 0 — Identify the project (mandatory, before anything else)

1. **Find the docs root**: in priority order — the `--docs` parameter; a directory in the
   repo/workspace that already has a spec structure (`features/` + `business-logics/` or an
   equivalent such as `specs/`, `docs/spec/`); if none exists, **ask the user** where to put it,
   then scaffold the standard structure (see "Standard structure" below).
2. **Project rules beat skill defaults — except the "business-only spec" principle**: if the docs
   root has its own authoring rules (CLAUDE.md, README, `_TEMPLATE` files…), read them all and
   follow them; the skill's "Default principles" and "Default outline" apply only where the
   project defines nothing. **Exception**: if the project's existing templates/docs embed
   implementation details (endpoints, class/function/file names, hooks, payloads…), that is
   technical documentation, not a business spec — **stop and ask the user** whether to follow the
   old format or this skill's business-only format; do not silently follow it.
3. **Identify the project's applications/tiers** (web admin, mobile, desktop, service/API…) from
   the workspace layout and the project's CLAUDE.md; identify the source repo for the module being
   documented. Single-application projects drop the `<app>` level in paths and IDs.
4. **Determine the documentation language**: follow the project's existing docs; for a new project
   ask the user (default Vietnamese).

## Standard structure (scaffold when the project has none)

```
<docs-root>/
  features/[<app>/]<module>.md          # screen & feature specs
  business-logics/[<app>/]<module>.md   # business rules & formula specs
  _trace/[<app>/]<module>.md            # spec → source-file mapping (internal, for doc maintainers)
  qa/                                   # test basis (owned by the testcase-gen skill)
```

Identifiers (file names in English kebab-case; app prefix uppercase, optional for
single-application projects):

- Feature: `<APP>-<MOD>-<NAME>` (e.g. `BO-INVC-FORM`)
- Business rule: `<APP>-BL-<MOD>-Rn` · self-verification scenario: `<APP>-BL-<MOD>-Vn`

## Default principles when writing specs

- **Business-only specs — no implementation.** Readers are BA/QA/Product; they must never need to
  open code. **Forbidden** in the document body: URLs/endpoints/HTTP methods; HTTP status codes
  (write "the system shows the error «…»" instead of "returns 422"); class/function/file/code
  module names; DB table/collection/column names; technical hook/query/state names; sample
  payloads/JSON; exception names. Refer to data fields by their **UI label**; use technical field
  names only when a field has no UI label. Allowed (business, not technical): verbatim UI
  strings/error messages, formulas + numeric examples, state tables, permission matrices, role
  names, screen/button names.
- **Technical traceability lives outside the spec**: record the "spec area → source file/function"
  mapping in a separate `_trace/<module>.md` in the docs root (a working file for doc maintainers,
  not a spec deliverable); the next update can still be checked against code without polluting the
  spec.
- **Write only what has been verified** — through source code, existing specs, or observation of
  the running software; leave unverified points out, never include guesses.
- Text the software actually displays goes verbatim in "double quotes"; your own descriptions go
  in (parentheses) — testers must be able to tell the two apart.
- Every number, formula, and example must match the source; **recompute numeric examples by hand**
  using the exact rounding rules in code before writing them down.
- One idea per line; explain terms/abbreviations at first use; no emoji, no arrows in place of
  words; keep every section of the outline — leave empty sections empty, write "Not applicable"
  where a lifecycle doesn't apply.
- Never record the authoring process ("as agreed…", "skipped this round…").

## Workflow

### 1. Survey the source code

Survey systematically (fan out with Agent/Explore subagents for large modules), collecting all of:

- **Navigation & screens**: routes, menus, screen list, table columns, toolbar buttons.
- **Interaction flows**: input forms, the steps users see and click, displayed results.
- **Validation & verbatim messages**: extracted from i18n/strings in code — only extracted strings
  may appear in "double quotes".
- **Formulas** (money, tax, points, quantities…): including **rounding mode and decimal places**,
  checked against the exact functions/constants in code.
- **States & lifecycle**: state enums, transition conditions, actions locked per state.
- **Permissions**: which roles see/do what; if the project has a central permission source, record
  only exceptions and point to that source.
- **Behavior-changing configuration/feature flags**: refer to them by their UI names; internal
  keys go only in the `_trace` file.
- **Technical traceability**: source file/function paths per area — written to
  `_trace/<module>.md`, never into the spec.

### 2. Write the spec against the outline

Use the project's `_TEMPLATE` if present; otherwise use the default outline below (and save it as
`features/_TEMPLATE.md` / `business-logics/_TEMPLATE.md` for next time):

**Features — per feature:** What is it? · When to use? · Preconditions · List screen · Main flows
(codes F1, F2…, multi-step actions numbered) · Business rules · Validation (table: when checked /
valid condition / message when invalid) · Data fields (by UI label) · States ·
State–action matrix · Permission–action matrix · Number formats & rounding · Empty & error states.

**Business Logic — per business domain:** Business context · Participating roles · End-to-end
process (pointing to Feature IDs) · Rules & calculation logic (codes `-Rn`, rounding spelled out) ·
**Worked numeric example** (the reference result tests will compare against) · States &
transitions · Error messages & constraints (each row usable as a negative test) ·
Behavior-changing configuration · **Self-verification** (codes `-Vn`, split into *Preconditions ·
Steps · Expected result* — the direct input for the testcase-gen skill).

For each module also produce `_trace/<module>.md`: a two-column table *Spec area (Feature ID / R
code) → source file/function* — an internal working file, not part of the spec.

Update the docs root's index/overview files (if any) so the new module is discoverable.

### 3. Handle doubtful points

Code that looks wrong/contradictory, or behavior without enough evidence to conclude: **keep it
out of the spec** — add a `GAP-NNN` row to the project's **Gap Log** (a gap-log file in the docs
root/qa; create it if missing), classified: **A** = behavioral doubt (bug candidate, must be
settled with dev/Product), **B** = documentation limit (missing spec/not yet checked against
code), with file:line evidence.

### 4. `--research` mode — gap-filling research

Runs after the code-derived spec exists, to catch **omissions reading code alone won't reveal**:

1. **Compare against the previous system / prototype**: find legacy/prototype repos of the same
   product in the workspace; check which old business rules the new version doesn't cover yet.
2. **Compare against the business domain**: identify the product's domain (retail, accounting,
   logistics…) and review it against standard domain knowledge — list business situations the
   spec doesn't address yet (use WebSearch for industry standards/regulations when needed).
3. **Cross-check applications**: does the same business rule present in several applications/tiers
   produce the same result — mismatches are type-A GAP candidates.
4. Handle findings: what **can be verified in code** goes straight into the spec; what **cannot**
   goes to the Gap Log (never mix guesses into the spec); **feature/improvement suggestions** go
   into a separate section of the final report, not into business documents.

### 5. Finish

- If the project has a link-check script, run it until 0 broken links; otherwise manually verify
  the relative links you added.
- Report to the user: files created/changed, counts of Feature IDs & BL Rules, newly opened GAPs,
  and (with `--research`) the list of omissions/suggestions.
- Do not commit/push unless the user asks.
