# Exhaustive case / story enumeration

This is the most important reference in the skill. Testing is only as good as the list of cases
you test. A flow you never wrote down is a flow that ships broken. Your job here is to think
**extremely long and hard** and surface **every** case, story, and state that can realistically
happen to this feature — not just the happy path you were shown.

> **The discipline:** assume your first list is missing half the cases. It always is. Generate,
> then deliberately attack your own list with "what else can happen?" until two consecutive passes
> add nothing new. Only then are you done enumerating. Under-enumerating is the #1 way this skill
> lets a bug through — over-enumerating only costs tokens, and we optimize for coverage over frugality.

---

## The process (do this every run, before decomposing into subagents)

1. **Restate the feature as a set of user goals.** What is each kind of user actually trying to
   accomplish? List every distinct goal, not just the one that was demoed.
2. **Walk every dimension below**, out loud, writing down each concrete case it surfaces for *this*
   feature. Skip a dimension only after you've consciously decided it doesn't apply — never by
   forgetting it. Most features touch 8–12 of these dimensions.
3. **Build the case list.** Each case = one row: `who · precondition/state · action · expected
   outcome`. A "case" is a distinct *story* (a path through the feature), not a single UI click.
4. **Self-audit — the "what's missing?" pass.** Re-read the list against the dimensions and ask the
   completeness questions at the bottom. Add what you missed. Repeat until a pass adds nothing.
5. **Prioritize, don't drop.** Tag each case P0 (happy path + data-loss/security/blocking),
   P1 (common edge/error), P2 (polish/rare). You test in that order and run as many as the parallel
   budget allows — but the *list* stays complete so coverage gaps are visible, never invisible.
6. **Map cases → flows → subagents.** Group related cases into flows (one subagent per flow). A
   single feature commonly yields far more than the "3–5 subagents" floor once enumerated honestly —
   that floor is a minimum, not a target.

---

## The dimensions — walk ALL of them

For each, ask the trigger question and write down every case it produces for this feature.

### 1. Actors & permissions (who)
- Every **role** that can reach this feature — test each one separately.
- **Unauthenticated** user hitting the URL directly. Expired/invalid session mid-flow.
- **Wrong role** — a user who should be blocked: does the UI hide it AND the API reject it (403)?
- **Ownership / multi-tenant isolation** — user A trying to view/edit/delete user B's resource by
  guessing the ID (IDOR). Org/tenant A seeing org B's data.
- First-time user (nothing set up yet) vs. returning user (existing data).

### 2. Happy paths & their variations (the success stories)
- The primary success path.
- **Alternate** success paths to the same goal (different entry point, keyboard vs. mouse, optional
  steps taken or skipped).
- All **optional fields filled** vs. **only required fields** vs. everything maxed out.
- Minimal valid input vs. rich/realistic input.

### 3. Input & validation (every field)
For each input: required-but-empty · too short / too long (boundary ±1 each side) · min/max numeric
(and 0, negative, decimals) · wrong format (email/phone/url/date) · wrong type · whitespace-only ·
leading/trailing spaces · duplicates / uniqueness conflict · special characters, Unicode, emoji,
RTL · injection probes (`<script>`, `'; DROP`, `{{7*7}}`) · pasting huge text · disallowed file
type/size on uploads. For each: is it rejected **clearly** (inline message in the right language)?

### 4. Entity state & lifecycle (status machine)
- Every **status** the entity can be in (draft, pending, approved, published, archived, deleted, …)
  — test the feature against each, because UI and permissions usually differ per status.
- Every **valid transition** between statuses — does it work and persist?
- Every **invalid transition** — is it blocked (no skipping/regressing where disallowed)?
- Soft-deleted / archived records: hidden where they should be, still referenced where needed.

### 5. Data quantity & boundaries (how many)
- **Empty state** — zero records. Is there a real empty UI, not a blank page or a crash?
- Exactly **one** item. **Many** items (pagination: first page, last page, single page, page
  boundary, "load more"). At/over the **maximum** allowed. Very long strings/lists overflowing layout.

### 6. Error & failure paths (when things go wrong)
- Server **4xx** (400 validation, 401, 403, 404 not found, 409 conflict, 422) and **5xx** — does
  the UI show a sane error, not a white screen or a silent swallow?
- **Network failure / offline / timeout / slow** response (loading + spinner shown, no double-submit).
- **Partial failure** — step 3 of 5 fails: is prior work preserved or rolled back coherently?
- Backend down / dependency down. (Watch for a 5xx masquerading as a CORS/`ERR_FAILED` in console.)

### 7. Concurrency & timing (race conditions)
- Two users (or two tabs) editing the **same record** — last-write-wins vs. conflict warning.
- **Double-click / double-submit** a button — one result, not two.
- Session **expires mid-flow**. Token refresh mid-request.
- **Browser back / forward / refresh** mid-flow — state coherent, no resubmission.
- Acting on a record another process just deleted/changed.

### 8. Persistence & idempotency (does it stick / repeat safely)
- After the action, **refresh** the page — did it persist? **Log out and back in** — still there?
- Do the same action **twice** — idempotent or correctly blocked, never silently duplicated.
- **Cancel / undo / abandon** mid-flow — no partial garbage left behind.

### 9. Navigation & flow control
- Direct-URL deep link into a mid-flow page (no prior context) — graceful redirect or guard.
- **Unsaved-changes** guard when navigating away. Modal/dialog: open, close, Escape, click-outside,
  confirm, cancel. Back button out of a modal.
- Interrupting a flow and resuming it later.

### 10. Search / filter / sort (if present)
- No-results query. Special-character query. Every filter individually + **all filters combined** +
  clear-all. Each sortable column asc/desc. Filter state surviving refresh / pagination.

### 11. Cross-module & cascading effects (ripples)
- Actions here that **change another module** (create an order → inventory drops; delete a parent →
  children cascade or block). Verify the *other* side actually reflects it.
- Shared status/enum constants consistent across modules.

### 12. UI/UX, responsive & accessibility states
- **Loading**, **empty**, **error**, **success/toast** states each render.
- Disabled/enabled button logic. Form reset after submit.
- Responsive: **mobile, tablet, desktop** breakpoints — nothing clipped, overlapping, or unreachable.
- Keyboard-only nav, focus order, visible focus, labels/contrast (basic a11y).

### 13. Localization & formatting
- **Every user-facing string** in the required language (no leaked default-language text).
- Date / number / currency / pluralization formatted per locale. Long translations not breaking layout.

---

## Completeness self-audit — ask before you stop

- For **every role**, did I cover what they CAN do *and* what they must be BLOCKED from?
- For **every input field**, an empty case, a boundary case, and an invalid case?
- For **every status** the entity has, a case in that status?
- Empty / one / many / over-limit for every list?
- A 4xx, a 5xx, and a network-failure case for every action that hits the server?
- A persistence-after-refresh check for every write?
- A cross-module ripple check for every action that isn't purely local?
- An isolation/IDOR check for every resource fetched or mutated by ID?
- Did the **last full pass add anything?** If yes, do another pass. If no, you're done.

If you genuinely cannot tell what the expected outcome of a case is, that's a **specification gap** —
list it as an open question for the user, don't silently drop the case.
