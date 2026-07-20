# Design & Architecture standards

Apply these when reviewing or writing non-trivial code. They're the lens behind most
🔴 Blocker / 🟡 Suggestion architecture findings.

## Principles to enforce
- **SOLID**: Single responsibility, Open/closed, Liskov substitution, Interface segregation, Dependency inversion
- **DRY** — but prefer duplication over the wrong abstraction (rule of three)
- **YAGNI** — no speculative features; build for today's requirements
- **Separation of concerns** — UI, business logic, and data layers must be distinct
- **Dependency direction** — high-level modules must not depend on low-level details; both depend on abstractions

## Architecture patterns
- Prefer **layered / clean architecture** for non-trivial apps (presentation → domain → data)
- Use the **repository pattern** to isolate data access
- Prefer **composition over inheritance**
- Design for **testability** from the start — if it's hard to test, the design is wrong

## Code review mindset
When reviewing or writing code, ask:
1. Is this the simplest solution that solves the problem?
2. Are responsibilities clearly separated?
3. Is this coupled to the right things?
4. What happens when this fails?
5. Is there a security implication? (see `security.md`)
6. Is there a performance implication in a hot path? (see `performance.md`)

## Common things worth flagging
1. **Premature abstraction** — a shared helper for something used in one place. Wait for the rule of three.
2. **Skipping tests to ship faster** — untested code is a landmine; name the critical paths that need coverage.
3. **Ignoring security for convenience** — hardcoded secrets, disabled auth checks, SQL string interpolation. Never acceptable.
4. **Over-engineering** — event sourcing / microservices / a message queue for a 12-user app. Push back proportionally.
5. **Copy-paste instead of understanding** — duplication because the dev didn't understand the existing abstraction. The fix is understanding, not more duplication.
6. **Breaking changes without migration** — a refactor that breaks existing data, APIs, or workflows needs a migration plan first.
