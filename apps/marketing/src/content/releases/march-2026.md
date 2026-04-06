---
title: 'New Open Source AI Releases — March 2026'
description: 'Notable open-source AI projects released in March 2026. Curated picks with context on what shipped and why it matters.'
month: 'March'
year: 2026
pubDate: 2026-03-31T00:00:00Z
faq:
  - question: 'What open source AI projects were released in March 2026?'
    answer: 'March 2026 saw major releases across the open-source AI coding space. Aider shipped v0.82 with improved repo mapping for large monorepos. Goose reached v1.0 with a stable desktop app and MCP plugin marketplace. Roo Code added JetBrains support in beta. OpenHands launched a free cloud tier with Minimax models. Kilo Code crossed 1.5 million users and became the top consumer on OpenRouter.'
  - question: 'What are the newest open source AI tools in March 2026?'
    answer: 'The newest entrants in March 2026 include several MCP-based tools and agent frameworks. Goose v1.0 was the biggest release with its stable desktop app. Most activity was updates to existing tools rather than brand-new projects, with Aider, Roo Code, Cline, and OpenHands all shipping significant versions.'
---

March was a month of consolidation in the open-source AI coding space. The big projects shipped stability updates rather than flashy new features, and the ecosystem around MCP continued to expand.

## Goose v1.0 — Stable Desktop App

[block.github.io/goose](https://block.github.io/goose) | Apache-2.0

Block shipped the v1.0 milestone for Goose, marking its desktop app as stable. The MCP plugin marketplace now has 50+ community extensions. The desktop app makes Goose the most accessible CLI-style agent — you get terminal power with a GUI fallback.

## Aider v0.82 — Better Monorepo Support

[aider.chat](https://aider.chat) | Apache-2.0

Aider's repo mapping, which scans your codebase to give the LLM context, previously hit memory limits on very large monorepos. v0.82 introduces chunked mapping that handles repos with 100k+ files. Also adds experimental multi-model support for using different models for different tasks within a single session.

## Roo Code — JetBrains Beta

[roocode.com](https://roocode.com) | Apache-2.0

Roo Code expanded beyond VS Code with a JetBrains plugin in beta. This puts it in direct competition with Kilo Code, which already supported JetBrains. The multi-mode system (Code, Architect, Ask, Debug) now works across both IDEs.

## OpenHands Free Cloud Tier

[openhands.dev](https://openhands.dev) | MIT

OpenHands launched a free tier of their hosted platform using Minimax models. Previously you needed your own API key or a paid plan. The free tier is limited but gives a zero-friction way to try autonomous AI development.

## Kilo Code — 1.5 Million Users

[github.com/Kilo-Org/kilocode](https://github.com/Kilo-Org/kilocode) | Apache-2.0

Kilo Code reported crossing 1.5 million users and becoming the highest-volume consumer on OpenRouter. For a Cline fork that launched less than a year ago, the growth rate is notable. JetBrains support remains its main differentiator from the parent project.

## Frontman — Astro + Vite Support

[frontman.sh](https://frontman.sh) | Apache-2.0 / AGPL-3.0

*Disclosure: We built this.* Frontman added Astro and Vite framework integrations alongside the existing Next.js support. The browser-based approach now works across the three most popular frontend build tools.

---

For a detailed comparison of all major open-source AI coding tools, see our [full comparison guide](/blog/best-open-source-ai-coding-tools-2026/).
