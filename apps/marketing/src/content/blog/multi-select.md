---
title: 'Multi-Select: Stop Fixing UI One Element at a Time'
pubDate: 2026-02-27T12:00:00Z
description: 'Select multiple elements in your running app, give each one instructions, and Frontman edits them all in one shot. Batch your UI fixes instead of context-switching for every nitpick.'
author: 'Frontman Team'
image: '/blog/multi-select-cover.png'
tags: ['announcement', 'developer-tools', 'ai']
faq:
  - question: 'What is multi-select in Frontman?'
    answer: 'Multi-select lets you hold Shift and click multiple UI elements in your running app, add separate instructions to each one, and have Frontman generate real source code edits for all of them in a single pass with hot-reload. Instead of fixing elements one at a time with separate round trips, you batch all your visual fixes into one operation.'
  - question: 'How does multi-select work under the hood?'
    answer: 'Frontman runs as middleware inside your dev server. When you click elements, it uses the framework source map to resolve each click target to a specific file and line number. Multi-select collects all resolved targets and their instructions, then generates a single coordinated set of edits. If multiple selections map to the same component file, that file gets read once and edited once with all changes.'
  - question: 'Which frameworks support Frontman multi-select?'
    answer: 'Multi-select is available in all Frontman integrations: Next.js, Astro, and Vite (React, Vue, Svelte). Install with npx @frontman-ai/nextjs install, npx @frontman-ai/vite install, or astro add @frontman-ai/astro.'
  - question: 'Can I use multi-select for code review feedback?'
    answer: 'Yes. Instead of filing separate review comments like "fix this copy" or "wrong padding here," you can open the running app, multi-select every issue, and generate the fixes yourself in one pass. This turns review feedback into committed code in under a minute.'
---

You know the loop. You spot a button that's 2px off. You click it, describe the fix, wait for the edit, confirm it looks right. Then you notice the header still says "Untitled." Click, describe, wait, confirm. Then the card below it looks wrong on mobile. Click, describe, wait, confirm.

Three fixes. Three round trips. Each one breaks your focus, each one costs a context switch between "looking at the app" and "talking to the AI." Multiply this by every visual nitpick in a typical development session and you've burned twenty minutes on what should have been a single batch operation.

This is the part of AI-assisted development that nobody talks about. The AI generates code fast. _You_ are the bottleneck — not because you're slow, but because the workflow forces you to be a serial queue. One fix at a time. One element at a time. One round trip at a time.

> **TL;DR:** Frontman multi-select lets you Shift-click multiple UI elements, add instructions to each, and fix them all in one shot. No more one-at-a-time round trips. It batches edits across shared files, generates real source code changes, and hot-reloads everything at once.

## How Multi-Select Works

Frontman now supports multi-select. Hold Shift, click every element that's bugging you, give each one its own instruction, and hit go. Frontman generates real source code edits for all of them in one shot, with hot reload.

The workflow:

1. **Click elements in your running app** — hold Shift to select multiple
2. **Add instructions to each** — "make this bold", "fix the padding", "change copy to 'Dashboard'"
3. **Frontman edits all of them** — real code changes, hot reload, one round trip

That's it. No more toggling between browser and editor for every tiny fix. No more losing your mental model of what needs changing while you wait for each individual edit to land.

<iframe width="100%" height="400" src="https://www.youtube-nocookie.com/embed/J3_OQzzEJPY" title="Frontman Multi-Select Demo" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen style="border-radius: 8px; margin: 2rem 0;"></iframe>

## Why One-at-a-Time Was the Bottleneck

Most AI coding tools treat each interaction as isolated. You select an element (or describe it in text), the AI processes it, generates an edit, and you verify. Then you start over for the next element with zero memory of the previous context.

This isn't just slow — it's architecturally wasteful. Each element you're fixing exists in the same component tree, the same page layout, the same design system. The AI re-reads the same files, re-parses the same DOM context, and re-generates the same boilerplate for each fix. Fix the padding on a card and the AI fetches the component file, parses the styles, generates the edit. Fix the header text on the same page and the AI does all of that again — potentially for the same file.

Multi-select eliminates this redundancy. Frontman collects all your selections and their instructions, resolves them against the live DOM and source map, and generates a single coordinated set of edits. If three of your selections map to the same component file, that file gets read once and edited once with all three changes.

## What This Looks Like in Practice

Consider a typical scenario: you're reviewing a dashboard page and notice five issues.

- The page title says "Page Title" (placeholder copy)
- A metric card has `padding: 8px` when the design system uses `padding: 16px`
- The "Export" button is using the wrong variant — should be `outline`, not `solid`
- A table header is misaligned
- The empty state message has a typo

Without multi-select, this is five separate interactions. Five context switches. Five times the AI reads the same page context. With multi-select, you Shift-click all five elements, type a short instruction for each, and submit once. Frontman maps each clicked element back to its source file and line through the live DOM-to-source mapping that comes from running as [framework middleware](/blog/runtime-context-gap/), then generates all five edits in a single pass.

The result lands with hot reload. You see all five fixes simultaneously. If one of them isn't right, you fix that one — but the other four are done.

## The Compound Effect

The real value isn't saving time on any single fix. It's that batch editing changes how you work. Instead of fixing things as you notice them — interrupting whatever you're actually doing — you accumulate a list. Browse the page, Shift-click everything that's off, describe the fixes, submit, move on.

This is closer to how designers work in Figma: select multiple layers, adjust properties, done. Except these are real source code edits in your actual codebase, not design file changes that need to be re-implemented.

It also changes the review workflow. Instead of filing five separate comments on a PR — "fix this copy", "wrong padding here", "button variant is off" — you can open the running app, multi-select every issue, and generate the fixes yourself in one pass. Turn review feedback into committed code in under a minute.

## How It Works Under the Hood

Frontman runs as middleware inside your dev server. When you click an element, it uses the framework's source map to resolve the click target to a specific file and line number. This is the same [runtime context](/blog/runtime-context-gap/) that makes single-element editing possible — the live DOM, computed styles, component tree, and server-side state are all available because Frontman is inside the framework, not observing it from outside.

Multi-select extends this by collecting multiple resolved targets and batching them into a single prompt. Each selection carries its own instruction and its own source mapping. The AI sees all of them together, which means it can reason about interactions between the edits — for example, if two selections target the same component, it can apply both changes without conflicts.

## Try It

Multi-select is available now in all Frontman integrations — [Next.js](https://frontman.sh), [Astro](https://frontman.sh), and [Vite](https://frontman.sh) (React, Vue, Svelte).

```bash
npx @frontman-ai/nextjs install
npx @frontman-ai/vite install
astro add @frontman-ai/astro
```

Open your app, hold Shift, click everything that's wrong, and fix it all at once.

Star it on [GitHub](https://github.com/frontman-ai/frontman) if batch-editing your UI sounds better than doing it one element at a time.
