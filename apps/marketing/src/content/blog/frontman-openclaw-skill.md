---
title: 'Use Frontman With OpenClaw'
pubDate: 2026-03-24T05:00:00Z
updatedDate: 2026-10-20T00:00:00Z
description: 'Frontman is now available as an OpenClaw skill. Give your AI agent the ability to click elements in a running web app, describe changes in plain English, and get real source file edits with hot reload. No IDE required.'
author: 'Danni Friedland'
articleSection: 'Product Announcement'
image: '/blog/frontman-openclaw-cover.png'
imageAlt: 'Frontman skill connecting OpenClaw to browser-based UI editing'
tags: ['openclaw', 'integration', 'ai-agents', 'open-source', 'browser-automation']
faq:
  - question: 'What is the Frontman OpenClaw skill?'
    answer: 'It is an OpenClaw skill that installs Frontman as a browser-based visual editing tool for your dev server. Once installed, your OpenClaw agent can open your running web app, click any element, and make source-level code edits based on natural language descriptions. Changes are written to real source files and hot-reloaded instantly.'
  - question: 'How do I install the Frontman skill in OpenClaw?'
    answer: 'Run openclaw skill install frontman-dev in your terminal. The skill detects your framework (Next.js, Astro, or Vite) and installs the appropriate Frontman plugin. Then start your dev server normally and open /frontman in your browser.'
  - question: 'Does Frontman replace OpenClaw browser automation?'
    answer: 'No. OpenClaw browser automation is general-purpose — it can navigate any website, fill forms, and extract data. Frontman is specialized for frontend development: it understands your component tree, computed CSS, source maps, and design system. They are complementary. Use OpenClaw for general web tasks and Frontman for precise UI editing in your own codebase.'
  - question: 'What frameworks does Frontman support?'
    answer: 'Next.js (App Router and Pages Router, including Turbopack), Astro (Islands, SSR, hybrid mode, content collections), and Vite (React, Vue, Svelte, SolidJS, SvelteKit). Frontman installs as a framework plugin with a single command.'
  - question: 'Is Frontman source-available?'
    answer: 'Yes. The browser client and JavaScript framework integrations are Apache-2.0, the WordPress plugin is GPL-2.0-or-later, and the server is AGPL-3.0-only with AI Supplementary Terms restricting AI training and AI-assisted competitive reproduction. Self-hosting is always an option. Bring your own API keys to Anthropic, OpenAI, or OpenRouter.'
  - question: 'Can designers and PMs use Frontman through OpenClaw?'
    answer: 'Yes. Since OpenClaw supports messaging channels like Slack, Telegram, and Discord, non-technical team members can describe UI changes in those channels. The OpenClaw agent with the Frontman skill handles the browser interaction, element selection, and code editing. The resulting diff goes through your normal code review process.'
---

Use OpenClaw to set up a supported project and open Frontman's editing workspace. Then use Frontman to inspect the selected UI, request a source change, and review the result.

The distinction is orchestration, not whether OpenClaw can access a browser. The [published skill instructions](https://github.com/frontman-ai/frontman/blob/main/openclaw-skill/SKILL.md#usage-with-openclaw) tell OpenClaw to interact with Frontman's browser interface; Frontman's own agent runs the visual editing loop.

### What the Skill Does

Install it with one command:

```bash
openclaw skill install frontman-dev
```

The skill adds Frontman to your OpenClaw agent's toolkit. Frontman installs as a plugin in your framework's dev server — Next.js, Astro, or Vite — and creates a browser-side MCP server that exposes:

- **The live DOM tree** — the actual rendered page, not just source files
- **Computed CSS** — runtime pixel values, not Tailwind class names
- **Component tree** — which component renders which DOM node, with exact source file and line number
- **Screenshots** — full visual context for the AI
- **Element selection** — click any element to target it for editing
- **Console logs and build errors** — piped from the dev server

For a request such as "fix the spacing on the hero section," the documented handoff is through Frontman's interface: OpenClaw opens the Frontman URL, selects the target through browser interaction, and submits the request in chat. Frontman's agent uses the available browser and framework tools to inspect and edit the project. Review the resulting page and source diff; the skill does not guarantee a correct edit.

### Why This Matters

The skill connects OpenClaw's orchestration workflow to Frontman's browser and framework tools. The [runtime context taxonomy](/blog/runtime-context-gap/#a-five-layer-context-taxonomy) explains the evidence layers; this guide focuses on connecting the two tools rather than repeating that architecture.

Keep the responsibilities clear:

1. OpenClaw uses its permitted shell and browser tools for project setup and opening the workspace.
2. In Frontman's interface, select the element and submit a bounded editing request.
3. Frontman's agent inspects available context and makes supported source edits.
4. Review the source diff, browser result, and checks before accepting the change.

### The Setup

If you already have OpenClaw running:

```bash
# Install the skill
openclaw skill install frontman-dev

# Install Frontman in your project (auto-detects framework)
# Next.js
npx @frontman-ai/nextjs install

# Astro
npx astro add @frontman-ai/astro

# Vite
npx @frontman-ai/vite install
```

Start your dev server and tell your agent to open `localhost:3000/frontman` (or whichever port your framework uses). Follow the [current installation guide](/docs/installation/) for Frontman sign-in, service access, and provider configuration.

### For Teams

The combination is especially useful for product teams. Designers and PMs do not need to learn an IDE or a terminal. They describe what they want changed in Slack — where OpenClaw is already listening. The agent uses Frontman to make the edit, takes a screenshot of the result, and posts it back to the channel. The engineer reviews the diff as a normal pull request.

Keep the normal [UI review loop](/blog/review-ui-changes-from-non-engineers/#the-review-loop): a message or screenshot is not merge approval. Task duration depends on the change, setup, and required review.

### Source-Available Frontman, Open-Source Integrations

Frontman's browser client and JavaScript framework integrations are Apache-2.0, and its WordPress plugin is GPL-2.0-or-later. Frontman Server is AGPL-3.0-only with [AI Supplementary Terms](https://github.com/frontman-ai/frontman/blob/main/AI-SUPPLEMENTARY-TERMS.md) restricting AI training and AI-assisted competitive reproduction, so the combined product is source-available. OpenClaw is MIT. The skill itself is published to ClawHub under MIT-0.

Browser tools run in your browser, and filesystem tools run on your machine through the framework integration. The hosted or self-hosted Frontman server orchestrates the loop and persists task history; relevant context passes through it to your selected LLM provider. You bring your own API keys. There is no vendor lock-in on either side.

---

The Frontman skill is available now on ClawHub. Install it, point your agent at your running app, and start shipping UI changes from your browser.

[GitHub](https://github.com/frontman-ai/frontman) | [Docs](https://frontman.sh/docs/) | [Discord](https://discord.gg/xk8uXJSvhC)
