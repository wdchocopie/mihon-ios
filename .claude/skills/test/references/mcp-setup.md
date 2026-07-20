# Playwright MCP setup for parallel testing

This skill drives several real browsers at once. Each browser comes from its **own Playwright MCP
server** — one MCP process = one browser, with its own serialized connection. To run N flows in
parallel you need N servers, each pinned to one subagent.

> **The user can simply ask Claude to set this up** — e.g. "install the Playwright MCP servers for
> /test" — and Claude configures them using the steps below (or the repo's `install.sh --playwright`).
> The user does not configure anything by hand. **One server gives zero parallelism**; to test flows
> simultaneously, configure one server per concurrent flow (**minimum 3, no upper limit**). New servers
> only connect after a Claude Code restart.

## Why multiple servers (not tabs / not subagents on one server)

A single Playwright MCP server is **one browser, one connection, serialized**. Multiple tabs share
that one session and pipe, so they can't act in parallel and they share cookies/login. Multiple
subagents pointed at the *same* server collide on the shared browser. The only clean way to get
true simultaneous, independent sessions is **multiple separate MCP servers**.

## Detect what's configured

Check both locations:
- **Project**: `<project>/.mcp.json`, and the project's block in `~/.claude.json` under `projects["<abs path>"].mcpServers`.
- **Global**: top-level `mcpServers` in `~/.claude.json`.

Look for keys named `playwright`, `playwright2`, `playwright3`, … (however many are configured —
there is no fixed number). The tools for each appear as
`mcp__<key>__*` (e.g. `mcp__playwright3__browser_click`). If memory already records that the user
has Playwright MCP, skip the "is it installed" check and just confirm the **count** is enough.

## Configure as many isolated servers as you want (minimum 3)

Add entries under different names. **The critical flag is `--isolated`**: without it, each server
uses the same persistent profile directory and they fight over the profile lock (the 2nd fails).
`--isolated` gives each a fresh in-memory profile — perfect for logging in as different
roles/users simultaneously.

Start with at least 3 (`playwright`, `playwright2`, `playwright3`):

```json
"mcpServers": {
  "playwright":  { "type": "stdio", "command": "npx", "args": ["@playwright/mcp@latest", "--isolated"], "env": {} },
  "playwright2": { "type": "stdio", "command": "npx", "args": ["@playwright/mcp@latest", "--isolated"], "env": {} },
  "playwright3": { "type": "stdio", "command": "npx", "args": ["@playwright/mcp@latest", "--isolated"], "env": {} }
}
```

**3 is the floor, not a cap.** Add `playwright4`, `playwright5`, … with the same shape for more
concurrency — there is **no upper limit**; configure as many as the user wants and the machine can
realistically run in parallel. Name them sequentially (no gaps) so the orchestrator can map flow *N*
→ the *N*-th server. Ask the user how many they want if it's unclear; otherwise add enough to cover
the run's flows (and never drop below 3).

Edit JSON programmatically (e.g. a small Python script) and **back up `~/.claude.json` first** —
it's a large shared config; a malformed write breaks the session. Validate the JSON after writing.

If the user wants persisted, separate logins instead of ephemeral profiles, swap `--isolated` for a
distinct `--user-data-dir=/tmp/pw-<n>` per server.

Other handy flags: `--headless` (no visible window, faster), `--browser chromium|firefox|webkit`,
`--viewport-size 1280,800`.

## Important: new servers need a restart

MCP servers connect **only at Claude Code startup**. After adding servers, tell the user to
**restart Claude Code** (and approve the new servers if prompted). You can confirm they're live by
checking that `mcp__playwright4__*` (etc.) appear as available/deferred tools — if a ToolSearch for
them returns nothing, they aren't connected yet.

## Capacity & waves

With **N** configured servers you can run **N** flows at once (keep N ≥ 3; no upper limit — add as
many as the machine handles). If a run needs more flows than servers, batch into **waves of ≤N**:
launch wave 1 (one subagent per server, all in one message), collect results, then reuse the same
servers for wave 2. Don't exceed one active subagent per server at a time.
