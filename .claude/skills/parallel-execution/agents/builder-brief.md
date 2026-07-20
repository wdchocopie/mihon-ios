# Builder dispatch brief

How the orchestrator should brief a builder subagent (`backend-builder`, `frontend-builder`,
`documenter`, or `general-purpose`) for one part of the plan. A builder starts with **none of
your context** — everything it needs to build the part correctly, and nothing about the other
parts, must be in the prompt.

**The prime rule: hand down everything you already learned.** By dispatch time you have
explored the codebase (Step 0 / deep-exploration) and distilled the shared canon into the
Step 2.5 context pack. All of it flows *into* the brief — pasted when small, pointed at
(`path:line` + one-line summary) when large — so the builder starts building immediately.
The test of a good brief: the builder's **first tool call opens a file in its lane**, not
`ls`/`grep` to orient itself. If the builder would need to open a file *outside* its lane
just to understand the task (a type it must conform to, a sibling component it must mirror,
a schema it writes against), that file's relevant content belongs in the brief. And tell the
builder so: *this brief is complete by design — don't explore the repo hunting for missing
context; if something genuinely isn't covered, make the smallest reasonable assumption and
flag it in your return.*

Include each of the following.

## What to put in the dispatch prompt

1. **The part, stated as a deliverable.** One or two sentences: what this builder is
   responsible for producing, end to end. e.g. "Build the `POST /api/orders` endpoint plus its
   service and request/response validation."

2. **File ownership — the lane.** The exact files/directories this builder may create or
   modify, and an explicit **out-of-scope** note for shared files it must NOT touch (another
   part owns them, or you'll edit them yourself after). This is what keeps concurrent builders
   from colliding.

3. **The relevant plan/spec text.** Paste the slice of the plan that governs this part — not
   the whole plan. Include any interface it must conform to (a shared type, an API contract a
   sibling part will call), so independent parts still fit together.

   **Hand over the shared contract verbatim.** If this part shares an interface with a sibling
   part in the same wave — a field/type shape, a request/response, CSS class names a renderer
   and stylesheet must agree on — give the builder the *exact* contract the orchestrator
   pinned down, not a paraphrase. This is what lets the two parts build concurrently in
   different files and still snap together, since neither has to wait on or guess the other.

4. **The context pack — the distilled shared knowledge.** Point at the Step 2.5 context pack
   (e.g. `.claude/plans/<feature>-context.md`) and say what's in it, so the builder reads one
   distilled file instead of re-deriving the canon from raw sources. For the parts of the pack
   this builder depends on most (its contract, the pattern it mirrors), paste the snippet
   directly into the brief as well — a pasted snippet beats even a file pointer.

5. **Project conventions and commands.** From your Step 0 grounding: the stack, the directory
   conventions, the language for user-facing strings, and the **type-check / lint / test
   commands** so the builder can self-check before returning.

6. **Acceptance criteria.** The concrete, checkable conditions the part must meet — these are
   the same criteria the tester will verify, so state them once and share them with both. e.g.
   "Endpoint returns 201 with the created order; rejects missing `customerId` with 400;
   persists to the orders table; passes `npm run typecheck`."

7. **The no-foreign-changes rule.** State it plainly: *create or modify only the files in your
   lane. Never revert, undo, or overwrite changes outside it — the working tree may hold the
   user's own edits or another builder's in-progress work.*

8. **Return format.** Tell the builder its final message IS the deliverable handed back to the
   orchestrator. It should return: the files it created/changed (`path` list), a short note on
   how it meets each acceptance criterion, the result of running the type-check/lint/test
   commands, and anything it couldn't finish or any assumption it had to make.

## Example brief

> **You are building one part of a larger plan: the Orders API.**
> Scope: implement `POST /api/orders` and `GET /api/orders/:id`, their service layer, and
> request validation.
> Files you own: `src/api/orders/*`, `src/services/orders.ts`. Do NOT touch
> `src/types/order.ts` (shared — already defines `Order`; import it) or `src/api/router.ts`
> (the orchestrator wires routes after you return).
> Spec: <relevant slice>. Contract: the request body matches `CreateOrderInput` from
> `src/types/order.ts` — pasted here verbatim: `interface CreateOrderInput { customerId:
> string; items: { sku: string; qty: number }[] }`.
> Context pack: `.claude/plans/orders-context.md` — holds the error-envelope shape, the
> service-layer pattern to mirror (copied from `src/services/users.ts`), and the DB schema
> for `orders`. Read it before writing code; don't re-derive any of it from the repo.
> Conventions: <stack, patterns>. Run `npm run typecheck && npm test src/api/orders` before
> returning.
> This brief is complete by design — don't hunt the repo for missing context; if something
> isn't covered, make the smallest reasonable assumption and flag it in your return.
> Acceptance criteria: 201 + created order on valid input; 400 on missing `customerId`;
> persists to DB; typecheck and the orders tests pass.
> Rule: modify only the files in your lane; never revert changes you didn't make.
> Return: files changed, how each criterion is met, the test/typecheck output, and any
> assumptions or unfinished bits.

## Sending a fix follow-up (Step 5)

When a tester returns FAIL, do **not** spawn a new builder — `SendMessage` the original
builder so it keeps its context. The follow-up should contain only what's new: the tester's
exact findings (repro steps, suspected `file:line`, severity) and the instruction to fix
those specific issues and re-confirm against the acceptance criteria. Keep it tight; the
builder already knows the part.
