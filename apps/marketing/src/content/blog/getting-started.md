---
title: 'Getting Started with Frontman'
pubDate: 2026-02-15T05:00:00Z
description: 'Stop filing tickets for button color changes. Frontman lets designers and PMs edit live UI components in the browser — no code, no waiting on dev sprints.'
author: 'Danni Friedland'
image: '/blog/getting-started-cover.png'
tags: ['tutorial', 'getting-started']
updatedDate: 2026-03-20T00:00:00Z
---

You want to change a button color. You open Figma, update the mock, tag a developer in a comment, wait for it to land in the sprint, wait for the PR, review the PR, notice the padding is off, leave another comment, wait for the fix, approve, wait for deploy. Three weeks for a button color.

That is not a tooling problem. That is a workflow problem. Frontman fixes it by letting you edit UI components directly in the browser, in plain English, without writing code.

### How It Works

Your engineering team runs one install command (Next.js, Astro, or Vite — they will know which). After that, anyone on the team can open the app in their browser and start making changes.

Click any element on the page. A selection overlay appears showing you the component. Then describe what you want:

```text
"Make this button larger and use our primary color"
"Increase the spacing between these cards"
"Make this heading match the one on the homepage"
"Hide this section on mobile"
```

The change appears in the browser immediately. The underlying code updates to match. Your engineering team reviews the diff just like any other change — clean, atomic, ready for their normal review process.

### Connect an AI Provider

Once installed, open your app in the browser and navigate to the Frontman overlay. Choose the AI provider you want to use:

- **Claude** — connect using provider connect
- **ChatGPT** — connect using provider connect
- **OpenRouter** — access multiple models with one key

Select your provider in the settings panel and follow the connect flow. If you already have an account with any of these providers, setup is done.

### It Respects Your Design System

This is the part that matters for teams with an established system. Frontman is not a generic code generator that outputs random CSS. It reads your project's conventions — your design tokens, your component patterns, your naming rules. When it makes a change, it uses _your_ system, not some default template.

If your team uses specific spacing scales, Frontman uses those values. If you have a token system for colors, Frontman references those tokens. The output follows the same rules your engineering team follows, because it reads the same configuration they do.

That means the changes you make through Frontman pass code review. They are not throwaway prototypes that need to be rebuilt "properly." They are production-quality edits that use your actual design system.

### What This Means for Your Team

**For designers:** Stop recreating components in Figma that already exist in code. Click the real component, describe the change, see it live. No more "this looks different in production" conversations.

**For PMs:** Unblock yourself on visual iteration. Test copy changes, layout tweaks, and responsive behavior without filing a ticket. Ship faster without adding to the dev backlog.

**For design system maintainers:** Every Frontman edit goes through your system's tokens and conventions. No one is injecting arbitrary hex values or hardcoded pixel sizes. Your system stays consistent even as more people contribute changes.

### Common Questions

**"Do I need to know how to code?"**
No. You describe changes in plain English. Frontman translates that into code that follows your team's conventions. You never see or touch the code unless you want to.

**"Will this break our design system?"**
The opposite. Frontman reads your project's conventions and design tokens. It uses your existing system rather than working around it. Every change it makes is a standard code change that goes through your team's normal review process.

**"What happens to changes I make?"**
They become real code changes, just like any edit a developer would make. Your engineering team can review, approve, or adjust them through their normal workflow. Nothing ships without their sign-off.

**"How does this fit into our existing workflow?"**
Frontman runs in your development environment. Changes show up as diffs that go through code review. It does not replace your process — it gives more people on your team the ability to propose changes directly, instead of describing them in tickets and hoping the intent survives the handoff.

### Get Started

Ask your engineering team to run the install command for your framework — it takes under five minutes. After that, open your app in the browser, connect an AI provider, and start clicking elements.

No training required. No migration. No new tool to learn beyond "click the thing, describe the change."

[Visit frontman.sh](https://frontman.sh) for full documentation and framework-specific install guides. Learn [why coding agents are blind to your UI](/blog/ai-coding-agents-blind-to-ui/), or read about [how Frontman keeps your code safe](/blog/security/).
