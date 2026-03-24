---
title: 'Frontman + OpenClaw: Visual Frontend Editing for Your AI Agent'
pubDate: 2026-03-24T05:00:00Z
description: 'Frontman is now available as an OpenClaw skill. Give your AI agent the ability to click elements in a running web app, describe changes in plain English, and get real source file edits with hot reload. No IDE required.'
author: 'Danni Friedland'
authorRole: 'Co-founder, Frontman'
image: '/blog/frontman-openclaw-cover.png'
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
  - question: 'Is Frontman open source?'
    answer: 'Yes. Client libraries and framework integrations are Apache 2.0. The server is AGPL-3.0. Self-hosting is always an option. Bring your own API keys to Anthropic, OpenAI, or OpenRouter.'
  - question: 'Can designers and PMs use Frontman through OpenClaw?'
    answer: 'Yes. Since OpenClaw supports messaging channels like Slack, Telegram, and Discord, non-technical team members can describe UI changes in those channels. The OpenClaw agent with the Frontman skill handles the browser interaction, element selection, and code editing. The resulting diff goes through your normal code review process.'
---

OpenClaw has changed how developers interact with AI agents. Instead of chatting in a terminal, you have an assistant that controls your browser, runs shell commands, manages files, and works across every messaging app you already use. It has 250,000+ GitHub stars for a reason.

But there is a gap in its browser capabilities when it comes to frontend development. OpenClaw's browser tool can click buttons, fill forms, and read pages — the same things a QA automation script does. What it cannot do is understand your component tree, read computed CSS values, resolve source map locations, or make targeted edits to the right source file when you point at a button and say "make this match the design system."

That is the problem Frontman solves. And now it is available as an OpenClaw skill.

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

When you tell your OpenClaw agent "fix the spacing on the hero section," it opens your app in the browser, uses Frontman's MCP tools to inspect the element, identifies the source component, generates the edit, and writes it to the file. Hot reload shows you the result. The whole loop happens in seconds.

### Why This Matters

Most AI coding tools work from source files. They read your JSX, guess what it renders, and hope the edit looks right. You do not see the result until you switch to the browser and check.

Frontman works backward. It starts from what you see in the browser — the rendered pixels — and traces back to the source. It knows that the card on screen is not just a `<div>` — it is your `Card` component from `@company/ui`, line 47 of `Card.tsx`, with a `box-shadow` that computes to `0 4px 6px rgba(0,0,0,0.1)`.

Combined with OpenClaw, you get an agent that can:

1. Run shell commands to set up your environment
2. Start your dev server
3. Open the app in the browser
4. Click elements and understand what they are at the component level
5. Make precise source-level edits
6. Verify the result visually through screenshots
7. Iterate until it matches the design

All from a single natural language instruction in Slack, Telegram, or your terminal.

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

Start your dev server and tell your agent to open `localhost:3000/frontman` (or whichever port your framework uses). The skill handles the rest.

### For Teams

The combination is especially useful for product teams. Designers and PMs do not need to learn an IDE or a terminal. They describe what they want changed in Slack — where OpenClaw is already listening. The agent uses Frontman to make the edit, takes a screenshot of the result, and posts it back to the channel. The engineer reviews the diff as a normal pull request.

This turns "can you move this 4px to the left" from a three-day ticket lifecycle into a thirty-second conversation.

### Open Source, All the Way Down

Both projects are open source. Frontman is Apache 2.0 (client) / AGPL-3.0 (server). OpenClaw is MIT. The skill itself is published to ClawHub under MIT-0.

Your code stays on your machine. Your conversations stay on your machine. You bring your own API keys. There is no vendor lock-in on either side.

---

The Frontman skill is available now on ClawHub. Install it, point your agent at your running app, and start shipping UI changes from your browser.

[GitHub](https://github.com/frontman-ai/frontman) | [Docs](https://frontman.sh/docs/) | [Discord](https://discord.gg/xk8uXJSvhC)
