---
name: roblox-docs
description: Check the official Roblox docs (create.roblox.com) instead of memory - method signatures, properties, enums, datatypes, deprecations, guides. Use whenever unsure about any Roblox/Luau API, when planning with less common or new APIs, or when asked "how do I X in Roblox".
---

# Official Roblox documentation

Roblox APIs change faster than model training data. A guessed signature costs the user a debugging cycle; a lookup costs a few hundred tokens.

## Lookup (cheapest first)

```
node tools/rbxkit.mjs docs --api TweenService:Create      # only that member: signature, params, notes
node tools/rbxkit.mjs docs --api task.wait                # libraries and globals too
node tools/rbxkit.mjs docs --api CFrame.new               # every overload
node tools/rbxkit.mjs docs --api Humanoid                 # class summary + member list
node tools/rbxkit.mjs docs --deprecated LoadAnimation     # deprecated? replacement?
node tools/rbxkit.mjs docs "how do I filter player text"  # semantic search (ENGLISH question)
```

Search in English with a full question (the index is semantic and English). Read a result `url` (already Markdown) with `curl -s <url>` or the agent's fetch tool.

Alternatives: Studio MCP `http_get` on the same `.md` URLs; MCP `skill` loads Roblox's built-in `rbx-*` skills (match the installed Studio version). Raw sources: append `.md` to any docs URL; search `https://create.roblox.com/docs/api/search?q=...`; indexes `/docs/llms.txt`, `/docs/reference/engine/llms.txt`, `/docs/cloud/llms.txt`; deprecated list `/docs/reference/engine/deprecated.md`.

## Rules

- Never guess URLs. Only `/docs/reference/engine/{classes|enums|datatypes|libraries|globals}/Name.md` is predictable; search for everything else. A 404 means a wrong path.
- Engine API (Luau in-game) and Open Cloud (HTTP from outside, `x-api-key`) are different systems.
- Check on the page: **Security** (Plugin/RobloxScript security can't be used in game scripts), **Thread Safety** (Parallel Luau), whether it **yields** (pcall; not inside non-yielding callbacks), **Deprecated** tags.
- Cite the URL (without `.md`) when explaining API behavior to the user.
- If the docs contradict a skill, the docs win; tell the user.
