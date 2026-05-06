---
title: 'How PMs Can Edit Production Websites Without Waiting on Devs'
pubDate: 2026-04-17T05:00:00Z
description: 'Frontman lets PMs click any element in the running application, describe the change, and open a pull request without touching a code editor or filing a ticket.'
author: 'Danni Friedland'
image: '/blog/edit-website-without-developer-cover.png'
tags: ['product-management', 'design-ops', 'cross-functional']
faq:
  - question: 'Do I need to set up a development environment to use Frontman?'
    answer: "No. Your engineering team installs Frontman once during initial setup. After that, you open the browser and start working. No terminal, no IDE, no local server setup required on your end. You work in the browser the same way you already review builds."
  - question: 'What kinds of changes can a PM make without a developer?'
    answer: 'Spacing, typography, colors, copy, button labels, CTAs, responsive layout adjustments, and component prop changes. Essentially: anything where the acceptance criterion is "it looks right" rather than "the logic is correct." Logic changes, API integrations, and data flow are still engineering work.'
  - question: 'Will I accidentally break something?'
    answer: 'The same safeguards that protect the codebase from engineering mistakes protect it from yours. Every change Frontman makes is a pull request. Your engineering team reviews the diff before anything merges. CI runs. Nothing ships without approval. You initiate the change; engineering controls what goes out.'
  - question: "How is this different from a CMS?"
    answer: "A CMS lets you edit content in a content management layer: blog posts, product copy, structured data. Frontman edits the actual UI components in your codebase. That includes spacing, layout, design system values, and component structure. Text is just one part of what you can change. It's the difference between editing what a component says and editing what a component looks like."
---

You caught a copy error on the pricing page at 4pm on a Tuesday. You know exactly what it should say. You could fix it yourself in about 30 seconds if someone handed you the right file.

Instead, you open Jira. You write a ticket. You label it "copy fix," assign it to the frontend team, set the priority, and attach a screenshot with an annotation. The ticket sits in the backlog until someone picks it up, usually 3 to 8 days later, depending on sprint priorities and who's on vacation. For a 30-second fix.

This isn't a process problem you can fix with better ceremony. It's an access problem. PMs can see what needs to change. They just can't make the change.

Frontman solves the access problem directly.

## How It Works

Frontman runs alongside your engineering team's development server. When they build the app locally or in a staging environment, Frontman is running too, and you can open it in your browser.

You see the live application. Click any element on the page and Frontman shows you which component it is, where it's defined, the current visual properties (spacing, color, font, content), and whether it's shared across the app or scoped to this page.

Describe what you want to change. Frontman edits the source file and hot-reloads the page. You see the result immediately. If it looks right, open a pull request for engineering to review.

No file names. No code. No terminal. No IDE. Just the browser you already use to review builds.

## What You Can Change

Copy is the obvious starting point: button labels, CTAs, headlines, body text, navigation labels, alt text on images, error messages, empty states. Most of the words users read are fair game.

Layout and spacing work the same way. Padding inside components, gap between elements, responsive behavior at specific screen sizes. If something looks cramped on mobile, you click it, say "fix this on mobile," and Frontman handles the adjustment.

Typography, background colors, border styles, component-level color changes: all accessible through the same click-and-describe workflow.

What doesn't work: changes involving business logic, data fetching, API integrations, or application state. Those are engineering tasks. Frontman handles the visual layer, where "correct" means "it looks right in the browser."

## The Ticket You Will Stop Filing

The most common PM tickets in any frontend team's backlog:

- "CTA copy should say X not Y"
- "Increase padding on mobile"
- "Button color should match the updated brand palette"
- "Pricing page heading font is wrong"
- "The hero section text is hard to read on tablet"
- "Fix the spacing in the footer"

Every one of these is a change the PM who filed the ticket could make directly if they had access. Every one of these takes a developer 10 minutes to fix and takes 3-5 days to reach them.

Frontman collapses that timeline. The PM makes the change, opens the PR, and engineering reviews a diff instead of translating a ticket. The whole loop goes from a week to under an hour.

## The Code Review Step

This is the part that matters for trust.

Every change you make through Frontman produces a standard pull request. Your engineering team sees exactly what changed, a diff against the existing code, line by line. They can comment, request changes, or approve. Nothing ships without that approval.

It's the same workflow as always: open a PR and get it reviewed before merging. The only difference is that you're opening the PR instead of a developer. Engineering still controls what goes out.

Your design system stays intact because you're editing the real components, not adding overrides. Your CI runs on your changes the same as any other PR. The codebase doesn't know you're not an engineer.

## A Real Workflow Example

Your marketing site is running a campaign. The hero section has a CTA button that says "Start Free Trial." Legal has asked that it say "Start Trial" before paid checkout launches.

**Before Frontman:**

```text
Day 1: PM notices the copy, drafts ticket, assigns to frontend
Day 2: Ticket lands in sprint planning
Day 5: Developer picks it up, finds the component, makes the change
Day 5: PM reviews staging, approves
Day 6: Merged and deployed
Total: 5 days, ~20 minutes of engineering time spread across context switches
```

**With Frontman:**

```text
11:00am: PM opens staging environment in browser
11:01am: PM clicks the CTA button in Frontman
11:01am: PM types "Change this to 'Start Trial'"
11:01am: Frontman edits the component, hot-reload confirms
11:02am: PM opens PR
11:30am: Engineer reviews the one-line diff, approves
11:35am: Merged and deployed
Total: 35 minutes, 5 minutes of engineering attention
```

Same outcome. Same review process. Completely different calendar cost.

## Getting Started

Frontman is set up once by your engineering team. It takes about 10 minutes to integrate with Next.js, Vite, or Astro. Follow the [integration guide](/docs/integrations/nextjs/) for your framework.

After setup, you get access to the staging environment in your browser and start clicking. No new tools to learn. No development environment to configure. The browser you already use to review builds is the tool.

Read about [how the code review workflow protects your codebase](/blog/security/), or see [how designers and PMs use Frontman alongside engineers](/blog/team-collaboration/).

[Try Frontman](https://frontman.sh) — open-source core for local development, with hosted plans coming soon.
