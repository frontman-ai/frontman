---
title: 'Frontman Quickstart: Change a Button Color in 5 Minutes'
pubDate: 2026-02-15T05:00:00Z
description: 'Install Frontman, connect an AI provider, and make your first live UI edit — all in under five minutes. This tutorial walks through one complete change from install to diff.'
author: 'Danni Friedland'
image: '/blog/getting-started-cover.png'
tags: ['tutorial', 'getting-started']
updatedDate: 2026-04-14T00:00:00Z
---

By the end of this tutorial, you will have installed Frontman, connected an AI provider, clicked a button in your running app, changed its color with a plain English instruction, and seen the source code update. Total time: about five minutes.

### Prerequisites

- Node.js 18 or later
- A project using Next.js, Vite (React, Vue, or Svelte), or Astro
- A running dev server (`npm run dev` or equivalent)
- An account with an AI provider (Claude, ChatGPT, or OpenRouter)

### Step 1: Install Frontman

Run the install command for your framework:

**Next.js:**
```bash
npx frontman@latest init --framework nextjs
```

**Vite (React, Vue, or Svelte):**
```bash
npx frontman@latest init --framework vite
```

**Astro:**
```bash
npx frontman@latest init --framework astro
```

This adds Frontman as a dev dependency and creates a one-line plugin entry in your framework config. You can check the diff — it touches one config file.

### Step 2: Restart Your Dev Server

Stop your dev server and start it again:

```bash
npm run dev
```

You should see `Frontman connected` in the terminal output. If you do not, check that the plugin line was added to your framework config — the init command prints the exact location.

### Step 3: Connect an AI Provider

Open your app in the browser. You will see the Frontman overlay in the bottom-right corner. Click it to open the settings panel.

Choose your AI provider:

- **Claude** — click Connect, follow the auth flow
- **ChatGPT** — click Connect, follow the auth flow
- **OpenRouter** — paste your API key (gives you access to multiple models)

If you already have an account with any of these providers, this step takes about thirty seconds.

### Step 4: Change a Button Color

Find any button in your app. Click it. The Frontman selection overlay appears, showing you the component name, file path, and current styles.

Now type:

```text
Make this button use our primary color
```

Frontman reads your project's design tokens, finds the primary color value, traces the button back to its source file, and applies the change. Hot-reload fires. The button updates in the browser.

Check your terminal or editor — the source file has changed:

```diff
- <button className="bg-gray-600 text-white px-4 py-2 rounded">
+ <button className="bg-primary text-white px-4 py-2 rounded">
    Get Started
  </button>
```

The diff is in your working tree. Run `git diff` to see it. This is a normal code change — your team reviews it like any other PR.

### Step 5: Iterate or Commit

If the result is not quite right, describe what is off:

```text
Use the darker shade — primary-700
```

Frontman applies the correction. Keep iterating until it looks right, then commit the change.

### What Just Happened

You clicked a live UI element, described a change in plain English, and Frontman:

1. Identified which component renders that element
2. Read its current styles (including resolved token values)
3. Found the source file and line number
4. Applied the edit using your project's conventions
5. Hot-reload showed you the result

No IDE. No file paths. No Tailwind class lookup. The change is real source code that goes through your normal review process.

### Next Steps

- [Full documentation and framework guides](https://frontman.sh)
- [What Frontman can and cannot do](/blog/frontman-launch/) — capabilities, tradeoffs, and how it fits into your team's workflow
- [How Frontman compares to Cursor and Claude Code](/blog/frontman-vs-cursor-vs-claude-code/)
- [Security model](/blog/security/) — how Frontman handles your source code
