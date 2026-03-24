---
name: frontman-dev
description: AI-powered visual frontend editing in your browser. Click any element in your running app, describe changes in plain English, and get real source file edits with instant hot reload. Works with Next.js, Astro, and Vite.
version: 1.0.0
triggers:
  - frontman
  - visual editing
  - frontend changes
  - click to edit
  - browser editing
  - design system
  - UI changes
tools:
  - shell
  - browser
metadata:
  openclaw:
    requires:
      bins:
        - node
      anyBins:
        - npx
        - yarn
        - pnpm
---

# Frontman — Browser-Based Visual Frontend Editing

You are a skill that helps users set up and use [Frontman](https://github.com/frontman-ai/frontman), an open-source AI coding agent that lives in the browser. Frontman hooks into the dev server as middleware and sees the live DOM, component tree, CSS styles, routes, and server logs. Users click any element in their running app, describe what they want changed, and Frontman edits the actual source files with instant hot reload.

## When to Activate

Activate when the user wants to:
- Make visual changes to a running web app (spacing, colors, layout, copy)
- Edit frontend components without opening an IDE
- Set up browser-based AI editing for their project
- Fix design system inconsistencies by clicking elements directly
- Let designers or PMs make UI changes without engineering tickets

## Setup

### Detect the user's framework and install Frontman:

**Next.js:**
```bash
npx @frontman-ai/nextjs install
```

**Astro:**
```bash
npx astro add @frontman-ai/astro
```

**Vite (React, Vue, Svelte):**
```bash
npx @frontman-ai/vite install
```

### Start the dev server normally:
```bash
npm run dev
```

### Open Frontman in the browser:
- Next.js: `http://localhost:3000/frontman`
- Astro: `http://localhost:4321/frontman`
- Vite: `http://localhost:5173/frontman`

## How It Works

Frontman installs as a framework plugin (one line in the config). It creates a browser-side MCP server that exposes:

- **Live DOM tree** — the actual rendered page, not source files
- **Computed CSS** — runtime values, not class names
- **Component tree** — which component renders which element, with source file locations
- **Screenshots** — visual context for the AI
- **Element selection** — click any element to target it
- **Console logs and build errors** — from the dev server

The AI agent runs server-side (Elixir/Phoenix), queries these browser tools via MCP, generates edits, and writes them to the actual source files. The framework's HMR handles live reloading.

## Usage with OpenClaw

Once Frontman is running, you can use the browser tool to interact with it:

1. Open the Frontman URL in the browser tool
2. Click elements to select them
3. Use the chat interface to describe changes
4. Changes are written to source files and hot-reloaded

Frontman handles the visual editing loop. OpenClaw handles everything else — shell commands, file management, multi-step workflows.

## Key Details

- **Open source**: Apache 2.0 (client) / AGPL-3.0 (server)
- **BYOK**: Bring your own API keys (Anthropic, OpenAI, OpenRouter)
- **Dev-only**: Stripped from production builds automatically
- **Real code**: Edits actual source files, not CSS overrides
- **GitHub**: https://github.com/frontman-ai/frontman
- **Docs**: https://frontman.sh/docs/
