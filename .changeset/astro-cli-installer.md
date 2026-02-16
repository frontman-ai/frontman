---
"@frontman-ai/astro": minor
---

Add CLI installer for `@frontman-ai/astro` with `npx @frontman-ai/astro install`.

- Detects Astro version, existing config/middleware files, and package manager
- Creates `astro.config.mjs` and `src/middleware.ts` with Frontman integration
- Supports host update on re-install, dry-run mode, and dependency installation
- AI-powered auto-edit for existing files via OpenCode Zen (free LLM, with privacy disclosure)
- Handles both `.ts` and `.js` middleware files
- Colorized CLI output with brand purple theme
