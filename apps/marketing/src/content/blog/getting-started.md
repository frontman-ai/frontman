---
title: 'Getting Started with Frontman: Next.js, Astro, and Vite'
pubDate: 2026-02-15T05:00:00Z
description: 'A quick guide to installing Frontman in your Next.js, Astro, or Vite project. One command, under 5 minutes, no configuration needed.'
author: 'Danni Friedland'
image: '/blog/getting-started-cover.png'
tags: ['tutorial', 'getting-started']
updatedDate: 2026-03-10T00:00:00Z
---

You find a new dev tool. The README says "Quick Start." You click it. Step one: install a global CLI. Step two: create a config file. Step three: add a plugin to your bundler. Step four: wrap your app in a provider component. Step five: set three environment variables. Step six: restart your dev server. Step seven: it does not work because you are using Turbopack and the plugin assumes Webpack. You open an issue. Someone replies "works on my machine." You close the tab.

One command. That is the entire Frontman setup. If your project runs `next dev`, `astro dev`, or `vite dev`, Frontman works. No config files. No environment variables. No step seven.

### [Next.js](https://nextjs.org/docs)

Supports App Router, Pages Router, and Turbopack.

```bash
npx @frontman-ai/nextjs install
```

That is the entire setup. The installer adds the Frontman middleware and development overlay to your project. Start your dev server as usual and open `localhost:3000/frontman`. No `next.config.js` changes. No wrapper components. No provider tree modifications.

### [Astro](https://docs.astro.build)

Works with SSR, SSG, and Islands architecture.

```bash
astro add @frontman-ai/astro
```

The Astro integration hooks into the build pipeline automatically. It respects your existing integrations and does not conflict with them. If you are using content collections, MDX, or custom renderers, none of that changes.

### [Vite](https://vite.dev/guide/)

Supports React, Vue, and Svelte projects.

```bash
npx @frontman-ai/vite install
```

The Vite plugin integrates with HMR directly. When Frontman edits a file, hot-module replacement fires the same way it does when you save a file in your editor. No special handling.

### Connect an AI Provider

Once installed, open your app in the browser and navigate to the Frontman overlay. Choose the AI provider you want to use:

- **Claude** — connect using provider connect
- **ChatGPT** — connect using provider connect
- **OpenRouter** — access multiple models with one key

Select your provider in the settings panel and follow the connect flow. If you already have an account with any of these providers, setup is done.

### What You Can Do Immediately

Click any element on the page. A selection overlay appears showing you the component name, file path, and line number. Then describe what you want in plain English:

```text
"Make this button larger"
"Change the background to blue"
"Add a 4px border radius"
"Reduce the padding on mobile"
```

Frontman edits the source file. Hot-reload fires. The change appears in the browser. The diff is in your working tree:

```bash
$ git diff
-  <button className="text-sm px-3 py-1.5 rounded">
+  <button className="text-base px-4 py-2 rounded-md">
```

One description, one edit, one diff. No tab-switching to verify. No "which file is this in?" No burning agent context describing what you see in the browser.

### It Reads Your Conventions

This is the part most people miss. Frontman is not a generic code generator. It reads your `agents.md` or `claude.md` file to understand your project's coding conventions — naming patterns, component structure, preferred utilities. When it edits code, it follows _your_ patterns, not some default template.

If your team uses a specific Tailwind preset, Frontman uses those classes. If you have a design token system, Frontman references those tokens. The output looks like code your team wrote, because it was informed by the same rules your team follows.

### Common Objections

**"One command? What is it actually doing?"**
The installer adds a dev-only middleware and a browser overlay component. You can inspect every file it adds — they are in your `node_modules` and your source tree. It is a dev dependency, not a black box. Run `git diff` after install to see exactly what changed.

**"What if it conflicts with my existing setup?"**
The framework integrations are designed to be additive. They do not modify your build config, override your middleware stack, or patch framework internals. If you have a complex custom setup and something breaks, `git checkout` reverses the install. In practice, conflicts are rare because Frontman hooks into the standard plugin/integration APIs that Next.js, Astro, and Vite already provide.

**"Do I need to install anything globally?"**
No. Everything is a project-local dev dependency. No global CLI, no daemon, no background process. When your dev server stops, Frontman stops.

### One Command

That is the honest setup. One command to install, connect your AI provider, and you are clicking elements in your browser and describing changes in English. The source files update. The browser hot-reloads. The diffs are ready for review.

No configuration guide. No "recommended settings." No second blog post explaining why the defaults are wrong. No step seven. It is a dev tool. It runs in dev. You install it in one command and it works.

[Visit frontman.sh](https://frontman.sh) for full documentation. Learn [why coding agents are blind to your UI](/blog/ai-coding-agents-blind-to-ui/), or read about [how Frontman keeps your code safe](/blog/security/).
