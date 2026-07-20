# US-XXX Story Title

## Status

planned | in-progress | done

## Lane

tiny | normal | high-risk

Anything touching user data integrity (backup import/export, library
database migration, download storage, extension runtime) is **always
high-risk**, regardless of code size.

## Product Contract

The behavior this story must make true. Link the Android module/screen it
ports (`android/...`) — that source is the behavioral spec.

## Relevant Docs

- `docs/ANDROID_TO_IOS_PLAYBOOK.md`
- `docs/decisions/NNNN-...md`

## Acceptance Criteria

- Criterion 1.
- Criterion 2.

## Risk Criteria (high-risk lane only)

- What must NEVER happen (e.g. "never loses or corrupts the user's library").
- What must ALWAYS happen (e.g. "backup import round-trips a real .tachibk file").

## Design Notes

- Swift types / modules touched:
- Persistence:
- Networking:
- UI surfaces:
- Divergences from Android original:

## Validation

| Layer | Expected proof |
| --- | --- |
| Unit (XCTest/Swift Testing) | |
| Integration | |
| Simulator run (manual/scripted) | |
| Parity check vs Android | |

## Evidence

Commands, reports, screenshots, links — added after validation exists.
