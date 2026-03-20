---
title: 'Frontman Launch: Ship UI Changes Without Waiting for Engineering'
pubDate: 2026-02-23T05:00:00Z
description: 'Click any element in your running app, describe changes in plain English, and watch them happen. Frontman gives designers and PMs direct access to UI fixes — no IDE, no ticket, no waiting. Open source, runs locally, your code never leaves your machine.'
author: 'Danni Friedland'
image: '/blog/frontman-launch-cover.png'
tags: ['announcement', 'open-source', 'ai', 'design-systems', 'collaboration']
updatedDate: 2026-03-10T00:00:00Z
---

You spot a problem in your app. Maybe the spacing between cards is wrong. Maybe a button color drifted from the design system three sprints ago and nobody caught it. You know exactly what the fix should be — you could describe it in one sentence.

But you can't fix it. You file a ticket. It sits in the backlog behind feature work. A developer picks it up, asks for clarification, pushes a fix, requests review. The whole thing takes days for what amounts to a one-line CSS change. Multiply that across every visual inconsistency, every "can we just tweak this" conversation, every design QA round that turns into a ticket factory.

This is the bottleneck. Not building new features. Not shipping big redesigns. The slow drip of small UI fixes that pile up because every single one requires an engineer to open an IDE.

### What Frontman Does

[Frontman](https://frontman.sh) is an open-source AI agent that lives inside your browser. Open your running app, click any element, and describe what you want changed in plain English. Frontman figures out which component renders that element, understands its current styles, and makes the edit. You see the result immediately.

No IDE. No ticket. No back-and-forth.

**What you see when you click an element:**

- Which component from your design system renders it — and where in the codebase it lives
- Its current styles, including computed values from tokens and variables
- How it sits in the layout relative to its neighbors

**What you can ask for:**

- "Match the spacing to what's in Figma — 24px gap, not 16"
- "This button should use the primary color from our design system"
- "Make this section stack vertically on mobile"
- "The heading font weight is wrong — it should be semibold"

Frontman maps the live element back to the exact source file and line number, gives the AI full visual context, and applies the change. Hot reload shows you the result in the browser right away. If it's not right, describe what's off and iterate — same as you'd do with a developer sitting next to you, except faster.

### For Teams With a Design System

If your company has a component library and design tokens — and you've felt the pain of those drifting out of sync across your product — this is where Frontman gets interesting.

Because it runs inside the dev server, Frontman can see your component tree. It knows that the card on screen isn't just a `<div>` — it's your `Card` component from `@company/ui`, with specific props and token-derived styles. When you ask for a change, it works within your system's components and tokens, not around them.

This means you can use Frontman to audit live UI against your design system. Click through screens in the running app and check whether the production output matches what's in Figma. When it doesn't, describe the correction. No screenshots, no Loom recordings, no "see the red circle in the attached image."

### How It Works (The Short Version)

Frontman installs as a plugin in your team's dev server — one line in the framework config. It supports Next.js, Vite (React, Vue, Svelte), and Astro. Your engineering team sets it up once; it takes about five minutes.

Once it's running, anyone on the team can open the app in their browser and access Frontman. It runs entirely on your machine. Your code and your conversations with the AI never leave your local environment — there are no external servers involved.

### What This Changes for Your Team

The usual workflow for visual fixes looks like this: designer spots a problem → files a ticket → developer picks it up → asks for context → pushes a fix → designer reviews → maybe another round. That's three to five days for a change that takes minutes to describe and seconds to apply.

With Frontman, a designer or PM can make that fix directly in the running app, in the actual codebase, using the actual design system components. The change shows up as a normal pull request for engineering to review. The code review step stays intact — engineers still approve what ships. But the ticket-and-wait loop disappears.

This matters most for teams that are scaling. When you have two or three squads shipping features, and a design system that needs to stay consistent across all of them, the number of small UI fixes doesn't grow linearly. It compounds. Every new screen is another surface where tokens can drift, spacing can be wrong, and components can be used in slightly off ways. Frontman lets the people who notice these problems fix them directly.

### Honest Tradeoffs

**What works well:**

- Visual fixes — spacing, color, typography, layout. The AI sees the live styles, so it knows _why_ something looks wrong, not just that it does.
- Design system consistency — click an element and immediately see which component and tokens are in play
- Design QA — walk through the live app and fix discrepancies on the spot instead of documenting them
- Onboarding — "what component renders this section?" is answered instantly, with the source file and line number

**What doesn't work well yet:**

- Complex interactions and state logic — Frontman sees visual output, not application state. Business logic changes still need an engineer.
- Performance work — it can't see render cycles or bundle sizes
- Large refactors — runtime context helps with surgical edits, not architectural changes
- Some frameworks aren't supported yet — Angular, Remix, and SvelteKit standalone don't have adapters

### Why Open Source

Frontman is Apache 2.0 (client libraries) and AGPL-3.0 (server). It uses a bring-your-own-key model — your code and AI interactions stay between you and your AI provider. Nothing routes through our servers. There's nothing to route through — there are no servers.

This isn't altruism. A tool that sits inside your dev server and sees your source code has to be open source. If your security team can't read every line of code that touches your codebase, they shouldn't sign off on it. We wouldn't either.

### Get Started

Setup takes about five minutes. Your engineering team runs one install command, adds one line to the framework config, and restarts the dev server. After that, anyone on the team can open the app and start using Frontman.

Full instructions: [frontman.sh](https://frontman.sh). Source code: [github.com/frontman-ai/frontman](https://github.com/frontman-ai/frontman).

Frontman is early-stage. There are rough edges. But if your team burns hours every week on the ticket-and-wait loop for visual fixes, [give it five minutes](/blog/getting-started/) and see if it changes the shape of your workflow.
