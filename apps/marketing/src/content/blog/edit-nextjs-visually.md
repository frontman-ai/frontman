---
title: 'How to Edit Any Next.js Component in Your Browser'
pubDate: 2026-04-14T05:00:00Z
description: 'Frontman connects to your running Next.js app and lets you click any element to edit the source. No file hunting, no class name guessing — just click and describe.'
author: 'Danni Friedland'
image: '/blog/edit-nextjs-visually-cover.png'
tags: ['nextjs', 'tutorial', 'developer-tools']
faq:
  - question: 'Do I need to eject from Next.js or change my build setup?'
    answer: 'No. Frontman runs as middleware in your existing Next.js dev server. You add a middleware.ts file, run your usual dev server, and open the browser. Nothing is ejected. Nothing is replaced. Your production build is unaffected.'
  - question: 'Does this work with the App Router?'
    answer: 'Yes. Frontman supports both the App Router and the Pages Router. It understands Server Components and Client Components and handles them appropriately — server-only components are edited in source, client components get live hot-reload verification.'
  - question: 'What happens when I click a shared component — does it change every instance?'
    answer: 'Frontman tells you before making the change. If you click a Button that appears in 12 places across your app, it will show you that the edit affects the shared component and where it is used. You can proceed (changing all instances) or narrow the change to a local override at that specific usage site.'
  - question: 'Can I use this without being a developer?'
    answer: 'Yes. Designers and PMs use Frontman to make visual changes — spacing, colors, typography, copy — without knowing which file to edit. Engineers set it up once. After that, anyone can click elements in the browser and describe changes in plain language.'
---

Most Next.js projects follow the same frustrating loop for visual changes: spot the issue in the browser, guess which file it's in, search for the class name, edit the wrong element, reload, try again. If you're a designer or PM, that first step ("guess which file it's in") is a wall you can't get past without an engineer.

Frontman removes that wall. You edit Next.js components by clicking them in the running browser, without hunting through files or guessing at class names.

## What "Edit Next.js Visually" Actually Means

When Frontman runs alongside your dev server, it connects to your running Next.js app and builds a map: every element you can see in the browser is linked to the exact component and file that renders it.

Click any element. You see:

- Which component renders it (e.g., `PricingCard` in `components/pricing/PricingCard.tsx`)
- The actual computed style values, not the class string
- Whether the styles come from a shared component or are scoped to this page
- Which props the parent is passing in

Describe what you want. Frontman edits the source file directly, and Next.js hot module replacement shows you the result immediately, in the same browser tab at the same scroll position.

## Setup: Two Minutes

**1. Run the installer:**

```bash
npx @frontman-ai/nextjs install
```

This adds the package and creates a `middleware.ts` file in your project root automatically.

**2. Run your dev server as usual:**

```bash
npm run dev
```

Open your browser. The Frontman sidebar appears. Click anything.

There is no step 3. Your production build is unaffected. Frontman is dev-only middleware.

## The Workflow

Here is what editing the hero section of a Next.js marketing page looks like:

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
Time: 8 minutes if you know the codebase. 45 minutes if you don't.
```

**With Frontman:**

```text
You: *click the heading in the browser*
Frontman: *selects the h1 in PageHero.tsx:23*
You: "Make this semibold instead of bold"
Frontman: *updates class, hot-reload fires*
You: *see correct result instantly, click the subheading*
You: "Same treatment"
Frontman: *edits, hot-reload fires*
Time: 30 seconds.
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

[Try Frontman](https://frontman.sh) — open-source core for local development, with hosted plans coming soon.
