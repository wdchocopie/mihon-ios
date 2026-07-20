# Testing strategy

Use this when reviewing test coverage or when the task is "write tests / improve testing".

## Test philosophy
- **Tests are first-class code** — apply the same naming and clarity standards.
- Tests are the safety net that enables refactoring; without them, you're guessing.
- Aim for the **testing pyramid**: many unit tests, fewer integration, fewest E2E.
- A test that's hard to write is signaling a design problem — fix the design.

## Test naming
Format: `[unit under test]_[scenario]_[expected behavior]`
- `calculateStreak_withNoBinges_returnsCorrectCount`
- `LoginScreen_whenEmailInvalid_showsErrorMessage`

## What to test
- **Business logic**: always — this is the core value.
- **Edge cases**: nulls, empty collections, boundary values, error paths.
- **Integration points**: real database/API calls where mock/prod divergence has burned us.
- **UI**: verify behavior, not implementation (what the user sees, not internal state).

## What NOT to test
- Framework internals
- Trivial getters/setters with no logic
- Code that will obviously be covered by a higher-level test

## Test quality checklist
- [ ] Test name clearly states what's being tested and the expected outcome
- [ ] One logical assertion per test (or tightly related assertions)
- [ ] No logic in tests (no `if`, `for`, `switch`)
- [ ] Tests are independent — no shared state between tests
- [ ] Tests fail for the right reason (not a setup issue)

## Automation
- Run linter + analyzer on every file save (CI signal)
- Run unit tests on every commit (pre-commit hook or CI)
- Run integration/E2E on every PR before merge
- Fail fast: a PR with failing tests does not merge
