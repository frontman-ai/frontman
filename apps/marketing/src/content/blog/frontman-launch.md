---
title: 'Frontman Launch: Ship UI Fixes From the Browser'
pubDate: 2026-02-23T05:00:00Z
description: 'Frontman is an open-source AI agent that connects to your browser and your dev server. Click any element, describe a change in plain English, and see it applied to your actual source code. Runs locally, code never leaves your machine.'
author: 'Danni Friedland'
image: '/blog/frontman-launch-cover.png'
tags: ['announcement', 'open-source', 'ai', 'design-systems', 'collaboration']
updatedDate: 2026-04-14T00:00:00Z
---

AI coding agents [cannot see your frontend](/blog/introducing-frontman/). They read source files and guess what the rendered output looks like. Frontman takes a different approach — it connects to your browser.

### What Frontman Does

[Frontman](https://frontman.sh) is an open-source AI agent that runs inside your browser alongside your dev server. Click any element in your running app and describe what you want changed in plain English. Frontman traces that element back to the exact source file and line number, applies the edit, and hot-reload shows you the result immediately.

**What you see when you click an element:**

- The component that renders it — name, file path, line number
- Its current styles, including computed values resolved through tokens and variables
- How it sits in the layout relative to its neighbors
- Which design system tokens are in play

**What you can ask for:**

- "Match the spacing to what's in Figma — 24px gap, not 16"
- "This button should use the primary color from our design system"
- "Make this section stack vertically on mobile"
- "The heading font weight is wrong — it should be semibold"

If the result is not right, describe what is off and iterate. Same as working with a developer next to you, except the feedback loop is seconds, not days.

### For Teams With a Design System

If your company has a component library and design tokens, this is where Frontman gets interesting.

Because it runs inside the dev server, Frontman has full [runtime context](/blog/runtime-context-gap/). It can see your component tree. It knows that the card on screen is not just a `<div>` — it is your `Card` component from `@company/ui`, with specific props and token-derived styles. When you ask for a change, it works within your system's components and tokens, not around them.

This means you can use Frontman to audit live UI against your design system. Click through screens in the running app and check whether the production output matches what is in Figma. When it does not, describe the correction. No screenshots, no Loom recordings, no annotated PDFs.

### How It Works

Frontman installs as a plugin in your framework's dev server — one line in the config file. It supports Next.js, Vite (React, Vue, Svelte), and Astro. Your engineering team sets it up once; it takes about five minutes. This [framework-aware](/blog/what-are-framework-aware-ai-coding-tools/) approach means Frontman understands your component structure, not just raw files.

Once running, anyone on the team can open the app in their browser and access Frontman. It runs entirely on your machine. Your code and your conversations with the AI never leave your local environment — there are no external servers involved.

### What Changes for Your Team

The usual workflow for visual fixes: designer spots a problem, files a ticket, developer picks it up, asks for context, pushes a fix, designer reviews, maybe another round. Three to five days for a change that takes minutes to describe.

With Frontman, a designer or PM makes that fix directly in the running app, in the actual codebase, using the actual design system components. The change shows up as a normal pull request for engineering to review. Engineers still approve what ships. The ticket-and-wait loop disappears.

This matters most for teams that are scaling. When you have multiple squads shipping features and a design system that needs to stay consistent, the number of small UI fixes compounds. Every new screen is another surface where tokens can drift and spacing can be wrong. Frontman lets the people who notice problems fix them directly.

### Honest Tradeoffs

**What works well:**

- Visual fixes — spacing, color, typography, layout. The AI sees the live styles, so it knows why something looks wrong, not just that it does.
- Design system consistency — click an element and immediately see which component and tokens are in play.
- Design QA — walk through the live app and fix discrepancies on the spot instead of documenting them.
- Onboarding — "what component renders this section?" is answered instantly, with the source file and line number.

**What does not work well yet:**

- Complex interactions and state logic — Frontman sees visual output, not application state. Business logic changes still need an engineer.
- Performance work — it cannot see render cycles or bundle sizes.
- Large refactors — runtime context helps with surgical edits, not architectural changes.
- Some frameworks are not supported yet — Angular, Remix, and SvelteKit standalone do not have adapters.

### Why Open Source

Frontman is Apache 2.0 (client libraries) and AGPL-3.0 (server). It uses a bring-your-own-key model — your code and AI interactions stay between you and your AI provider. Nothing routes through our servers. There is nothing to route through — there are no servers.

This is not altruism. A tool that sits inside your dev server and sees your source code has to be open source. If your security team cannot read every line of code that touches your codebase, they should not sign off on it. We would not either. Read more about our [security model](/blog/security/).

### Get Started

Setup takes about five minutes. Your engineering team runs one install command, adds one line to the framework config, and restarts the dev server. After that, anyone on the team can open the app and start using Frontman.

Full instructions: [frontman.sh](https://frontman.sh). Source code: [github.com/frontman-ai/frontman](https://github.com/frontman-ai/frontman).

Not sure what the fuss is about? Read [why every AI coding agent is blind to your UI](/blog/introducing-frontman/) first. Ready to try it? [Change a button color in five minutes](/blog/getting-started/).
