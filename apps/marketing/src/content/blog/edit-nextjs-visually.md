---
title: 'Edit Next.js Components in Your Browser'
pubDate: 2026-04-14T05:00:00Z
updatedDate: 2026-10-20T00:00:00Z
description: 'Use Frontman for browser-led edits in a supported Next.js app. Understand setup, source-mapping limits, shared components, and a reproducible next exercise.'
author: 'Danni Friedland'
articleSection: 'Tutorial'
image: '/blog/edit-nextjs-visually-cover.png'
imageAlt: 'Next.js component selected for visual editing in the browser'
tags: ['nextjs', 'tutorial', 'developer-tools']
faq:
  - question: 'Do I need to eject from Next.js or change my build setup?'
    answer: 'No. Frontman runs inside supported Next.js dev servers through middleware on Next.js 15.x (15.5 minimum) or proxy on Next.js 16.x. You run your usual dev server and open the browser. Nothing is ejected or replaced. The package runtime only handles routes in NODE_ENV=development by default.'
  - question: 'Does this work with the App Router?'
    answer: 'Yes. Frontman supports both the App Router and the Pages Router. It understands Server Components and Client Components and handles them appropriately — server-only components are edited in source, client components get live hot-reload verification.'
  - question: 'What happens when I click a shared component — does it change every instance?'
    answer: 'An edit to a shared implementation can affect other instances. Ask the agent to identify shared impact, review actual callers and the source diff, and prefer instance-level props when the request is local. Do not assume the tool automatically finds every usage or prevents a broad change.'
  - question: 'Can I use this without being a developer?'
    answer: 'Yes. Designers and PMs use Frontman to make visual changes — spacing, colors, typography, copy — without knowing which file to edit. Engineers set it up once. After that, anyone can click elements in the browser and describe changes in plain language.'
---

Most Next.js projects follow the same frustrating loop for visual changes: spot the issue in the browser, guess which file it's in, search for the class name, edit the wrong element, reload, try again. If you're a designer or PM, that first step ("guess which file it's in") is a wall you can't get past without an engineer.

Frontman removes that wall. You edit Next.js components by clicking them in the running browser, without hunting through files or guessing at class names.

## What "Edit Next.js Visually" Actually Means

Frontman combines the selected element's browser context with source metadata exposed by the framework integration. Source mapping can be missing or incomplete, so not every element resolves to an exact file and line.

Depending on available metadata, a selection can include:

- Which component renders it (e.g., `PricingCard` in `components/pricing/PricingCard.tsx`)
- The actual computed style values, not the class string
- Whether the styles come from a shared component or are scoped to this page
- Which props the parent is passing in

Describe what you want. Frontman edits the source file directly, and Next.js hot module replacement shows you the result immediately, in the same browser tab at the same scroll position.

<span id="setup-two-minutes"></span>

## Set Up the Next.js Integration

**1. Run the installer:**

```bash
npx @frontman-ai/nextjs install
```

This adds the package and creates the correct Next.js entrypoint automatically: `middleware.ts` for Next.js 15.x (15.5 minimum) or `proxy.ts` for Next.js 16.x. If your app uses `src/app` or `src/pages`, the file is created under `src/`.

**2. Run your dev server as usual:**

```bash
npm run dev
```

Open `/frontman` on the development server, complete Frontman sign-in, and connect a supported model provider. Follow the [current setup guide](/docs/integrations/nextjs/) for requirements and troubleshooting; provider access is not supplied by installing the package.

The supported editing workflow is development. The generated entrypoint can remain in production builds, but the package runtime only handles routes when `NODE_ENV=development` by default. Set `FRONTMAN_ENABLE_IN_PRODUCTION=1` or `FRONTMAN_ENABLED=1` to opt in outside development. Set `FRONTMAN_ENABLED=0` to force it off.

## The Workflow

The following sequences illustrate the handoff difference; they are not recordings or measured timing results. For a complete exercise, [follow the reproducible Next.js overflow tutorial](/blog/tutorial-nextjs-runtime-context/#1-create-a-page-with-a-known-bug).

**Without Frontman:**

```text
You: *notice hero heading has wrong font weight in browser*
You: *open VS Code, search for "hero" across 47 files*
You: *find HeroSection.tsx, look for the heading class*
You: *wrong file — this is the HomeHero, not the PageHero*
You: *find PageHero.tsx, locate the h1 class*
You: *change font-bold to font-semibold, save*
You: *check browser* — correct component, but the subheading also needs fixing
You: *find the subheading, update that too, save*
```

**With Frontman:**

```text
You: *click the heading in the browser*
Frontman: *uses the selected element's available source context*
You: "Make this semibold instead of bold"
Frontman: *updates class, hot-reload fires*
You: *see correct result instantly, click the subheading*
You: "Same treatment"
Frontman: *edits, hot-reload fires*
```

## What You Can Change

Frontman isn't limited to simple style tweaks. In a Next.js project, you can change:

- Layout and spacing: padding, margin, gap, responsive breakpoints, grid and flex properties
- Typography: font weight, size, line height, letter spacing, text color, font family
- Colors, borders, opacity, shadows, and gradients
- Copy inside components: text content, alt text, button labels
- Prop values passed to shared components from layout pages

For changes that involve logic, routing, or data fetching, that's engineering work and the right tool is Cursor or Claude Code. Frontman handles the visual layer: the part where "correct" means "it looks right in the browser."

## App Router: Server and Client Components

If your project uses the Next.js App Router, Frontman handles the client/server boundary automatically.

For Client Components (`'use client'`), edits trigger hot-reload immediately. For Server Components, Frontman prompts you and handles the page refresh. The workflow is the same either way: click, describe, see the result.

You don't need to know which type a component is. Frontman knows.

## What Happens to Your Code

Frontman edits your actual source files, not a copy or a shadow DOM overlay. The same files your engineers work in.

That means:
- Changes show up in `git diff` as normal diffs
- Your team reviews them in pull requests
- CI runs on them like any other change
- Your design system conventions stay intact, because Frontman is editing code that already follows them

Generated code from tools like v0 or Bolt creates a parallel codebase you have to maintain. Frontman edits the codebase you already have. See [how that distinction plays out in practice](/vs/v0/).

## Getting Started

If you have a Next.js project running locally, setup takes under two minutes. Follow the [Next.js integration guide](/docs/integrations/nextjs/) for the full walkthrough, or read about [how Frontman connects to your framework](/blog/frontman-launch/).

[Try Frontman](/frameworks/) — self-host in one command or use hosted Frontman Pro now. The browser client and JavaScript integrations are Apache-2.0, the WordPress plugin is GPL-2.0-or-later, and Frontman Server is AGPL-3.0-only with AI Supplementary Terms.
