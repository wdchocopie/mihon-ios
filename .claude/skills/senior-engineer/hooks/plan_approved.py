#!/usr/bin/env python3
"""PostToolUse:ExitPlanMode hook — fires when the user approves a plan (Claude Code only).

Injects a JUDGMENT-PRESERVING nudge: steer the senior-engineer plan->persist->build
lifecycle only when the change is substantive; tell the model to just build directly when
it's small. Never forces parallel-execution on a trivial plan.
"""
import sys, json

def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # never block on a parse error
    if data.get("tool_name") != "ExitPlanMode":
        sys.exit(0)
    resp = data.get("tool_response") or {}
    file_path = resp.get("filePath") or ""
    context = (
        "A plan was just approved"
        + (f" (Claude Code auto-saved it at {file_path})" if file_path else "")
        + ". Apply senior-engineer judgment before building: if this is a SUBSTANTIVE, "
        "multi-part change, follow the plan->persist->build lifecycle — copy the approved "
        "plan into the repo at .claude/plans/<slug>.md under a clean, committable name, then "
        "execute via the parallel-execution skill (dependency waves, disjoint file ownership, "
        "per-part tester->fix loop). If the change is SMALL or trivial, skip that ceremony and "
        "just implement it directly. Do not over-engineer a one-file change."
    )
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": context}}))
    sys.exit(0)

if __name__ == "__main__":
    main()
