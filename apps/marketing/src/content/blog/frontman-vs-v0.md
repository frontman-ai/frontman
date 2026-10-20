---
title: 'From a v0 Prototype to a Reviewed Frontend Edit'
pubDate: 2026-04-16T05:00:00Z
updatedDate: 2026-10-20T00:00:00Z
description: 'Plan a bounded pricing-card spacing edit after a v0 prototype reaches your repository. Keep source review, responsive checks, and release approval explicit.'
author: 'Danni Friedland'
articleSection: 'Tutorial'
image: '/blog/frontman-vs-v0-cover.png'
imageAlt: 'Frontman and v0 workflows for editing existing codebases'
tags: ['tutorial', 'ai', 'developer-tools']
faq:
  - question: 'Can v0 work with an existing repository?'
    answer: 'Yes. Its GitHub documentation describes importing existing repositories and working through branches, previews, and pull requests. Do not evaluate it as a tool that can only generate fresh components.'
  - question: 'Can I use v0 output and then edit it with Frontman?'
    answer: 'Once the code is in a project covered by a supported Frontman integration, you can evaluate Frontman for further browser-led source edits. A developer must set up the integration, and resulting changes still need source and application review.'
  - question: 'Does editing existing components guarantee design-system consistency?'
    answer: 'No. Either workflow can produce incorrect or inconsistent changes. Review token usage, shared-component impact, responsive behavior, accessibility, and the actual source diff.'
---

Your pricing section already exists. You want more space between the cards—not a second implementation of the entire section.

This walkthrough plans that bounded edit after a prototype has reached your repository. It is an illustrative procedure, not a timed comparison or a recorded successful run. We built Frontman. For product selection and maintained feature comparisons, use [Frontman vs v0](/vs/v0/); this article owns the narrower handoff from prototype to reviewed change.

## Before You Start

You need an existing project supported by a [Frontman framework integration](/docs/reference/compatibility/), a developer who can complete setup, and a normal branch/review process. Frontman's JavaScript editing workflow uses the development server, not a production deployment.

[v0's GitHub documentation](https://v0.app/docs/github) describes importing existing repositories and working with branches and pull requests. You can continue there rather than switching tools. The Frontman path below is an option when you prefer to start the next edit from the running app.

## 1. Record the Existing Pricing Section

Create a working branch and record the starting revision. Open the page locally, note the viewport where the cards feel crowded, and capture a screenshot. Identify whether the spacing comes from the section container, a shared card, or a responsive rule before proposing a change.

Do not assume new code is inherently harder to maintain or that existing code is already correct. Both need review. The intended acceptance criterion is one spacing change without altering copy, prices, checkout links, or unrelated card instances.

## 2. Request a Scoped Change

After [setting up Frontman](/blog/getting-started/), select the relevant section in the running preview. An example request:

> Inspect what controls the spacing between these pricing cards. Propose the smallest change that increases the gap at the affected width while preserving our existing spacing tokens. Keep copy, prices, checkout links, and other card instances unchanged. Explain any shared-component impact before editing.

Source metadata can help identify the responsible file, but it may be unavailable. If the agent cannot locate the right rule reliably, stop and investigate the source rather than accepting a visual override blindly.

## 3. Review the Source Diff

Check that the diff changes the intended container or breakpoint rule, not a duplicate component or a global token affecting the whole site. Review any new hardcoded value against your spacing scale. A small diff can still change shared behavior.

Frontman edits source through its framework integration; it does not replace your git or pull-request workflow. Use the [engineering review checklist](/blog/review-ui-changes-from-non-engineers/#what-engineers-should-check) before accepting the change.

## 4. Verify and Release Through Your Normal Process

Check the affected width and other supported widths. Confirm that card copy, links, keyboard behavior, and adjacent content still work. Run the project's normal checks and inspect other pages if the changed component is shared.

If the edit does not meet the acceptance criterion, revert the scoped change on the working branch. Merge and deploy only through your team's existing approval process. Neither tool choice nor a convincing preview guarantees a correct result.

## Choose the Next Task, Not a Permanent Tool Boundary

You can continue repository work in v0 or evaluate Frontman for browser-led iteration once the project is running locally. Keep the same review standard either way.

For a reproducible exercise rather than this proposed pricing task, follow the [Next.js mobile-overflow tutorial](/blog/tutorial-nextjs-runtime-context/#1-create-a-page-with-a-known-bug). For the broader decision, return to the [Frontman/v0 comparison](/vs/v0/).

**Correction, October 20, 2026:** The earlier version characterized v0 as fresh-code generation only, gave unsubstantiated task-time comparisons, and implied existing-component editing inherently preserves a design system. Those claims are withdrawn; this is now an explicitly illustrative workflow with source and responsive review requirements.
