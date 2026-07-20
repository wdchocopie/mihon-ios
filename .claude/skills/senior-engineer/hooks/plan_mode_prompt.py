#!/usr/bin/env python3
"""UserPromptSubmit hook — nudges senior-engineer's plan lifecycle in plan mode (Claude Code only).

Fires on every prompt; exits silently unless permission_mode == "plan". The nudge is
judgment-preserving: engage the lifecycle for substantive code/feature planning, plan
directly for trivial or non-code tasks.
"""
import sys, json

def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    if data.get("permission_mode") != "plan":
        sys.exit(0)  # only act while planning; stay silent everywhere else
    context = (
        "You are in plan mode. If this is a substantive code or feature planning task, engage "
        "the senior-engineer skill and its plan->persist->build lifecycle: investigate first "
        "with deep-exploration, then write an execution-ready plan (concrete parts, "
        "independent-vs-sequential dependency waves, file/module ownership per part, and "
        "per-part verification) before calling ExitPlanMode. If the task is trivial or "
        "non-code, just plan it directly — don't over-engineer."
    )
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": context}}))
    sys.exit(0)

if __name__ == "__main__":
    main()
