---
title: 'Multi-Select: Fix Design Drift Across Your Entire App at Once'
pubDate: 2026-02-27T12:00:00Z
description: 'Spot inconsistencies across teams? Shift-click every off-brand element, describe what it should look like, and Frontman fixes them all in one pass — real code changes, no tickets filed.'
author: 'Danni Friedland'
image: '/blog/multi-select-cover.png'
tags: ['announcement', 'design-systems', 'ai']
updatedDate: 2026-03-10T00:00:00Z
video:
  name: 'Frontman Multi-Select Demo'
  description: 'See how Frontman multi-select lets you Shift-click multiple UI elements in your running app, add instructions to each, and fix them all in one shot with real source code edits and hot reload.'
  youtubeId: 'J3_OQzzEJPY'
  thumbnailUrl: '/blog/multi-select-cover.png'
faq:
  - question: 'What is multi-select in Frontman?'
    answer: 'Multi-select lets you hold Shift and click multiple UI elements in your running app, add separate instructions to each one, and have Frontman fix all of them in a single pass. Instead of filing separate tickets for every design inconsistency, you batch all your visual fixes into one operation that produces real code changes.'
  - question: 'Can designers and PMs use multi-select without writing code?'
    answer: 'Yes. You describe fixes in plain language — "match this to our primary button style," "fix the spacing to 16px," "update this copy." Frontman translates your instructions into real source code edits. No IDE, no pull request workflow, no waiting for a developer to pick up the ticket.'
  - question: 'Which frameworks support Frontman multi-select?'
    answer: 'Multi-select is available in all Frontman integrations: Next.js, Astro, and Vite (React, Vue, Svelte). Install with npx @frontman-ai/nextjs install, npx @frontman-ai/vite install, or astro add @frontman-ai/astro.'
  - question: 'How does multi-select help maintain a design system?'
    answer: 'When multiple teams ship features against the same design system, inconsistencies are inevitable. Multi-select lets you open any page, Shift-click every element that drifts from the system — wrong spacing, off-brand colors, incorrect component variants — and fix them all at once. It turns design QA from a reporting step into a fixing step.'
---

You're doing a design QA pass. The dashboard a feature team shipped last week has a button using the wrong variant. The spacing on the metric cards doesn't match your system. A header still says placeholder copy. The empty state uses an icon you deprecated two months ago.

You know exactly what each fix should be. But you can't make them. You open a ticket for the button. Another for the spacing. Another for the copy. Another for the icon. Four tickets, four handoffs, four items competing for engineering bandwidth against actual feature work. Maybe they get fixed this sprint. Maybe next.

This is the bottleneck nobody talks about in design systems at scale. The system is defined. The violations are obvious. But the people who spot them — designers, PMs, design system leads — can't fix them. The feedback loop between "seeing the problem" and "shipping the fix" runs through a ticket queue.

> **TL;DR:** Frontman multi-select lets you Shift-click multiple UI elements in the running app, describe the fix for each in plain language, and apply all changes in one shot. No tickets, no handoffs. It produces real code changes that match your design system — not a mockup that still needs implementation.

## How Multi-Select Works

Open your running app. Hold Shift and click every element that doesn't match your design system. Describe the fix for each one in plain language. Hit go. Frontman makes real code changes for all of them at once.

The workflow:

1. **Click elements in the running app** — hold Shift to select multiple
2. **Describe the fix for each** — "use the outline button variant", "match the system spacing (16px)", "update copy to 'Team Dashboard'"
3. **Frontman fixes all of them** — real code changes, live preview, one pass

No tickets filed. No developer context-switching away from feature work. You saw the problem, you described the fix, it's done.

<iframe width="100%" height="400" src="https://www.youtube-nocookie.com/embed/J3_OQzzEJPY" title="Frontman Multi-Select Demo" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen style="border-radius: 8px; margin: 2rem 0;"></iframe>

## Why the Ticket Queue Was the Real Bottleneck

The problem was never that fixes are hard. A wrong button variant is a one-line change. Wrong spacing is a one-line change. But when the person who spots these issues can't make the change directly, every one-line fix becomes a ticket, a handoff, a prioritization decision, and a review cycle.

Multiply that across teams. Your design system serves three, four, five feature teams. Each team ships UI that mostly follows the system — but "mostly" means dozens of small violations per sprint. The design system team becomes a QA function that files tickets they can't resolve themselves.

Multi-select changes the economics. Instead of reporting violations, you fix them. Frontman resolves each clicked element to its actual source file, understands the component tree and design system context, and generates coordinated edits across all your selections. If three issues map to the same component, it handles them in one edit.

## What This Looks Like in Practice

Your growth team just shipped a new onboarding flow. You're doing a QA pass and spot five issues:

- The page title still says "Page Title" — placeholder copy that slipped through review
- Card spacing is 8px instead of 16px — doesn't match the design system
- The "Get Started" button uses the solid variant — should be outline per your system's CTA rules
- A table header is misaligned with the rest of the page
- The empty state message has a typo

Before multi-select, this is five tickets. Five handoffs to a developer who has to context-switch away from feature work. Five items in a backlog competing with actual product priorities. Some of these might not get fixed for weeks.

With multi-select, you Shift-click all five elements, type a short instruction for each, and submit once. Frontman maps each element back to its source file through the live [DOM-to-source mapping](/blog/runtime-context-gap/) that comes from running inside the framework. All five fixes land at once. You see the corrected page immediately. If one fix isn't quite right, you adjust that one — the other four are done.

Total time from spotting the issues to shipping the fixes: under a minute.

## Design System Consistency at Scale

The real value isn't saving time on any single fix. It's closing the loop between the people who define the system and the code that implements it.

When your design system serves multiple teams, drift is inevitable. Team A interprets the button guidelines one way, Team B another. Spacing gets approximated. Copy doesn't match the content spec. The design system team catches these in QA — but until now, catching them and fixing them were two completely separate steps with a ticket queue in between.

Multi-select makes QA and fixing the same step. Browse the app, Shift-click everything that's off, describe each fix, submit. It works the way you already work in Figma — select multiple layers, adjust properties, done. Except these are real code changes in the actual codebase, not design file edits that still need to be implemented.

This changes the dynamics between design and engineering. Instead of being the team that files polish tickets nobody prioritizes, the design system team becomes the team that [keeps the product consistent — directly](/blog/team-collaboration/).

## How It Works Under the Hood

Frontman runs as middleware inside your dev server — it's part of the app, not a browser extension or screenshot tool. This is how [framework-aware AI tools understand your design system](/blog/what-are-framework-aware-ai-coding-tools/) at the source level. When you click an element, it resolves the click to the actual source file and line number using the framework's source map. It sees the live DOM, the component tree, computed styles, and your [design system context](/blog/runtime-context-gap/).

Multi-select collects all your selections and batches them into a single coordinated edit. Each selection carries its own instruction and source mapping. Frontman reasons about all of them together — if two fixes target the same component, both changes land in one clean edit without conflicts.

## Try It

Multi-select is available now in all Frontman integrations — [Next.js](https://frontman.sh), [Astro](https://frontman.sh), and [Vite](https://frontman.sh) (React, Vue, Svelte). Your engineering team adds one line to the dev server config:

```bash
npx @frontman-ai/nextjs install
npx @frontman-ai/vite install
astro add @frontman-ai/astro
```

Then anyone on the team — designer, PM, design system lead — can open the running app, hold Shift, click everything that drifts from the system, and fix it. [Getting started](/blog/getting-started/) takes five minutes.

Star it on [GitHub](https://github.com/frontman-ai/frontman) if you've ever wished you could fix design inconsistencies yourself instead of filing tickets.
