---
"@frontman/frontman-core": minor
---

Add `list_tree` tool for project structure discovery during MCP initialization. The tool provides a compact, monorepo-aware directory tree view that is injected into the system prompt and available as an on-demand callable tool. Supports workspace detection (package.json workspaces, pnpm, turbo, nx), smart noise filtering, and git-aware file listing.
