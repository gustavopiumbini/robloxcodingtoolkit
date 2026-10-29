# One-prompt setup: existing Roblox project

You are an AI coding agent (Claude Code, Codex, or similar). Add the Roblox Vibe Coding Toolkit to the user's existing Roblox project without breaking anything, then do the task that came with this file (if any). Work autonomously; stop to ask only where this file says **ASK**. Reply in the user's language.

## 1. Inspect (read-only)

- Find the project root and how code reaches Studio: Rojo (`*.project.json`), Argon, Studio Script Sync, or no files at all (code only inside the place).
- Map the layout: where server, client and shared code live; frameworks (Knit, Matter, Fusion, ProfileStore...); package manager (Wally); existing `AGENTS.md`/`CLAUDE.md`; git status (uncommitted work?).
- Check tools: `node` 18+, `rokit`, `rojo`, Studio MCP tools available to you.

## 2. Install the toolkit (non-destructive)

- Uncommitted changes → **ASK** whether to commit first.
- `npx --yes github:gustavopiumbini/robloxcodingtoolkit install .` (adds skills to `.claude/skills/` and `.agents/skills/`, `AGENTS.md`/`CLAUDE.md` only if missing, `tools/rbxkit.mjs`). Never pass `--force` over existing agent files.
- If the project already had `AGENTS.md`/`CLAUDE.md`: append a short "Roblox toolkit" section pointing to the skills and `tools/rbxkit.mjs` commands instead of replacing them.
- Rewrite the **Map** section of `AGENTS.md` to match this project's real layout and frameworks. If the project uses different patterns than the template (e.g. Knit instead of Init/Start bootstraps, ProfileStore instead of DataService), state in `AGENTS.md` that the project's patterns win.
- Optional, only if they fit: copy `Util/Guard`, `Util/RateLimiter`, `Util/Signal`, `Util/Trove` from the toolkit `template/src/shared/` and `template/src/dev/` (DevTools for 3D building) into the matching folders.

## 3. Baseline audit

- `node tools/rbxkit.mjs check` over the source folders; summarize by severity (don't fix yet).
- If the project has no files on disk (Studio-only), explain the trade-off and **ASK** whether to set up Rojo (export the scripts to files) or keep editing through Studio MCP.

## 4. Connect Studio

Same as the new-game recipe: Rojo plugin (`rojo plugin install`) + `rojo serve` (background) when the project uses Rojo; Studio MCP via Assistant → Manage MCP Servers → Quick connect, then restart the agent and say "continue Roblox setup".

## 5. Task and hand-over

- If the user gave a task, do it with the `roblox-feature` skill (or `roblox-review` for audits, `roblox-debug` for errors).
- Final message: what was installed/changed, the audit summary with the top 3 fixes, what you verified, and 3 suggested next prompts.
