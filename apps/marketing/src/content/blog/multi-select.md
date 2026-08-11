---
title: 'Fix Design Drift With Multi-Select'
pubDate: 2026-02-27T12:00:00Z
description: 'Use Frontman annotations to select multiple UI elements, attach element-specific instructions, submit one prompt, and review the resulting source changes as a batch.'
author: 'Danni Friedland'
image: '/blog/multi-select-cover.png'
imageAlt: 'Frontman multi-select for fixing design drift'
articleSection: 'Product Announcement'
tags: ['announcement', 'design-systems', 'ai']
updatedDate: 2026-07-30T00:00:00Z
video:
  name: 'Frontman Multi-Select Demo'
  description: 'See how Frontman annotations let you select multiple UI elements in a running app, add instructions, and send their visual and source context in one prompt.'
  youtubeId: 'J3_OQzzEJPY'
  thumbnailUrl: '/blog/multi-select-cover.png'
faq:
  - question: 'What is multi-select in Frontman?'
    answer: 'Frontman annotation mode lets you select multiple elements before sending a prompt. Use repeated clicks, or Meta+Shift and drag to annotate meaningful elements inside a rectangle. Each annotation is enriched with available visual, DOM, and source context.'
  - question: 'Can designers and PMs use multi-select without writing code?'
    answer: 'They can select rendered elements and add plain-language comments without locating source files manually. The output is still source code and should be reviewed, tested, and approved through the team repository workflow.'
  - question: 'Which frameworks support Frontman multi-select?'
    answer: 'Frontman documents annotation source detection for React, Vue 3, and Astro projects. Source location can be unavailable when framework metadata or source detection fails, but the annotation can still include screenshot, selector, and other captured context.'
  - question: 'How does multi-select help maintain a design system?'
    answer: 'It packages several visible inconsistencies into one prompt with ordered annotations and optional element-specific comments. The agent may process them as independent tasks or one coordinated change; reviewers must still inspect actual diff scope and shared-component impact.'
---

Design QA often finds several related issues on one screen: a stale label, inconsistent card spacing, and a button using wrong existing variant. Treating each observation as a separate prompt loses shared page context. Treating all of them as one vague instruction makes review harder.

Frontman annotations provide a concrete middle path: select each rendered element, attach its requirement, and send selected context together.

> **TL;DR:** enter annotation mode, select multiple elements with clicks or rectangle selection, add optional comments, and submit one prompt. Frontman sends ordered annotation context to agent. Agent decides whether work is independent or coordinated. Review resulting source diff; multi-selection does not guarantee one file, conflict-free edits, or correct design-system usage.

## Exact Selection Workflow

1. Open Frontman workspace and load relevant page in web preview.
2. Click cursor icon to enter annotation mode. Cursor becomes crosshair and hovered elements highlight.
3. Click elements one at a time. Each receives numbered badge and optional comment popup.
4. For rectangle selection, hold **Meta+Shift** and drag over a group. Current client implementation checks browser `metaKey` and `shiftKey` values.
5. Add element-specific comments when requirements differ.
6. Wait until annotation enrichment finishes. Send is disabled while annotation remains in progress.
7. Submit annotations with shared chat instruction, or submit annotated comments without extra text.
8. Inspect rendered result and source diff before keeping change.

<iframe width="100%" height="400" src="https://www.youtube-nocookie.com/embed/J3_OQzzEJPY" title="Frontman Multi-Select Demo" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen style="border-radius: 8px; margin: 2rem 0;"></iframe>

## What Each Selection Contains

Frontman attempts to enrich each annotation with:

- Element screenshot
- CSS selector, tag, classes, nearby text, and bounding box
- Framework-derived component name and source location when available
- Bounded component context where integration supports it
- Comment entered by user

Annotations are sent as structured resources alongside prompt. Agent receives ordered annotated-element context and screenshots. This reduces ambiguity about which rendered nodes user means; it does not prove which source change is correct.

## Concrete Batch Example

This example is illustrative, not a customer incident or benchmark.

Suppose onboarding page has three independent observations:

| Annotation       | Comment                                            | Constraint              |
| ---------------- | -------------------------------------------------- | ----------------------- |
| Page heading     | `Replace placeholder with "Create your workspace"` | Copy only               |
| Card row         | `Use existing spacing-4 token between cards`       | No new token            |
| Secondary action | `Use existing outline variant`                     | Preserve click behavior |

Submit shared instruction:

```text
Apply comments to these annotations. Keep changes on this page,
reuse existing tokens and variants, and do not change routing,
event handlers, state, or shared defaults.
```

Good result is not "three fixes happened at once." Good result is reviewable evidence:

- Diff touches only files required by requested changes
- Existing token and variant APIs are reused
- Event handlers and behavior remain unchanged
- Browser result matches comments at relevant viewports
- Automated checks pass

## Selection Constraints

### Rectangle selection is geometric

Drag operation finds visible, meaningful elements whose bounding rectangles overlap selection rectangle, then favors more specific descendants over matching ancestors. It does not understand design intent. Review numbered annotations and remove accidental selections before sending.

### Source detection can fail

Framework metadata, source maps, cross-origin behavior, or timeout can prevent source location resolution. Annotation remains usable with available screenshot and DOM context, but agent may need to search. Do not claim every selected element maps directly to exact file and line.

### Multiple selections are not atomic edits

Agent decides whether to create independent tasks or coordinated change. Selected elements may resolve to one file, several files, shared component, or generated output. There is no guarantee of one edit, no conflicts, or unchanged unrelated usages.

### Shared components expand blast radius

Several selected instances can point to same component. Changing shared implementation may affect unselected pages. Prefer instance-level props when intent is local; require code-owner review when shared default changes.

### Navigation clears live annotations

Annotations refer to current DOM elements. Navigating or reloading destroys those references and clears active annotations. Batch one stable page state at a time.

## Expected Diff and Review Behavior

Before accepting output, inspect:

1. **File scope:** Did only relevant source files change?
2. **Selection coverage:** Does each requested annotation have corresponding change, and no extra change?
3. **Shared impact:** Did agent alter reusable component or token definition rather than intended instance?
4. **Instruction conflicts:** If comments conflict, did agent expose or silently choose between them?
5. **Code quality:** Are existing components, tokens, utilities, and conventions preserved?
6. **Behavior:** Did event handlers, accessibility semantics, responsive states, and data flow remain intact?
7. **Verification:** Does browser result match request, and do project checks pass?

Keep batch small enough that reviewer can map each annotation to diff hunk. Split unrelated pages or risk classes into separate prompts and pull requests. No universal selection count is safe; diff comprehensibility is governing limit.

## When to Use Multi-Selection

Use it for related, visible corrections sharing one page or review context. Avoid batching unrelated redesign, logic changes, dependency work, and shared-system migrations merely because elements can be selected together.

For complete annotation behavior and fallback rules, read [Annotations](/docs/using/annotations/) and [Web Preview](/docs/using/web-preview/). For ownership of resulting changes, read [Design System Collaboration Without Tickets](/blog/team-collaboration/).

Start with [Frontman installation](/docs/installation/), then test multi-selection on a branch with normal review controls.
