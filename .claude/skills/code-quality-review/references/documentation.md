# Documentation hygiene

Code tells you *what* the system does today; documentation tells you *why* it was built
that way and *how* the pieces fit. After implementing or reviewing changes, assess whether
docs need to catch up — and surface it as a dedicated `📝 Documentation` section in the
review output.

## When to suggest doc updates
- **New feature or module** — document the purpose, key decisions, and usage in the appropriate existing doc (workflow doc, data dictionary, user journey). If none covers this area, suggest creating one.
- **Changed domain model** — update the data dictionary / domain model docs with new or changed fields, entities, or relationships.
- **New or changed workflow** — update workflow or user-journey docs to reflect the new steps.
- **Architectural decision** — if the change involves a non-obvious trade-off, suggest an ADR (Architecture Decision Record).
- **API changes** — if endpoints were added, removed, or changed, ensure API docs or relevant workflow docs reflect it.

## When NOT to suggest doc updates
- Bug fixes that don't change behavior or interfaces
- Internal refactors with no external behavior change
- Trivial changes (renaming, formatting, dependency bumps)
- Changes already covered by inline comments or auto-generated docs

## How to suggest — always be specific
Name the file, the section, and what changes:
```
📝 Documentation:
- Update `docs/domain/data-dictionary.md` § "Inventory" — add `transferZoneId` field
- Create `docs/decisions/005-event-sourcing-inventory.md` — document why event sourcing was chosen over CRUD
- No doc update needed — internal refactor with no behavioral change
```
