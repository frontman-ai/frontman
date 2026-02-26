---
title: 'Breaking the Wall Between Design, Product, and Engineering'
pubDate: 2026-02-16T05:00:00Z
description: 'Every pixel adjustment routes through a developer. Frontman lets designers and PMs make UI changes directly, with code review.'
author: 'Frontman Team'
image: '/blog/team-collaboration-cover.png'
tags: ['collaboration', 'workflow']
---

Here is how a one-line CSS change actually ships at most companies:

1. A designer spots a spacing issue on staging
2. The designer files a ticket: "Hero section padding too large on mobile"
3. The ticket sits in the backlog for two days
4. A developer picks it up, opens the file, and immediately asks: "Which hero section? Can you send a screenshot? Which breakpoint?"
5. The designer sends a screenshot with a red circle drawn in Preview
6. The developer makes the change, opens a PR
7. The designer reviews, says "close but can you make it 4px less"
8. Another commit, another review cycle
9. Merged. Three days for a padding change

Three days. Six context switches. Two people blocked on each other across timezones. For this:

```diff
-    <div className="p-6 max-w-2xl mx-auto">
+    <div className="p-4 max-w-2xl mx-auto">
```

One character. Three days. This is not a process failure. This is what happens when only one role in the organization can touch the code. Every visual change — no matter how trivial — must be serialized through a developer. The developer becomes a bottleneck not because they are slow, but because the system requires them for changes they do not need to think about.

### The Frontend Collaboration Bottleneck

Look at that nine-step workflow again. The actual work — changing a class name — takes thirty seconds. The other two days and twenty-nine minutes are _communication_. Filing the ticket. Explaining the ticket. Clarifying the ticket. Reviewing the result. Requesting a tweak. Reviewing again.

The complexity of the change is near zero. The overhead of routing it through the right person is enormous. This is not a problem you solve with better ticketing software. You solve it by letting the person who sees the problem fix the problem.

### What That Looks Like

With Frontman, the same scenario plays out differently:

1. Designer opens the app in their browser
2. Clicks the hero section
3. Types: "Reduce padding by 8px on mobile"
4. Frontman edits the source file and hot-reloads
5. Designer sees the result, adjusts if needed, commits
6. Developer reviews a clean one-line diff in the PR

Five minutes. One person. Zero tickets. The developer still reviews the code — quality does not drop. But the developer reviews a _finished change_ instead of playing telephone across Slack and Jira for three days.

### Who Does What

- **Designers** adjust spacing, colors, typography, and layout directly in the browser. They click what they want to change and describe the change in plain English. No IDE. No file paths. No Git commands.
- **PMs** fix copy, update CTAs, and tweak content. The typo that has been on the landing page for two weeks because nobody wanted to file a ticket for it? Gone in thirty seconds.
- **Developers** review PRs instead of making trivial pixel changes. They focus on architecture, performance, data fetching, and the problems that actually require engineering judgment.

Every change still goes through code review. Every change is a standard Git diff. The workflow is the same — the routing is different.

### Common Objections

**"Designers will ship bad code."**
Designers are not writing code. They are describing changes in English, and Frontman is editing the source files. The output is a diff that goes through code review. If the diff is bad, it does not get merged. This is the same gate that catches bad code from anyone — junior developers, contractors, AI assistants. The review process does not care who authored the change.

**"This will create chaos in the codebase."**
Every change is a Git commit on a branch. It goes through the same PR process as any other change. There is no backdoor. There is no "apply directly to main." If your team has branch protection and review requirements, those apply to Frontman changes exactly the same way. If your team does not have branch protection, you have a bigger problem than Frontman.

**"Non-developers won't understand the impact of their changes."**
They do not need to. Frontman shows the result immediately via hot-reload. If the change breaks the layout, they see it. If it looks wrong, they undo it. The developer who reviews the PR understands the impact — that is what code review is for. You do not need every contributor to understand the full system. You need the reviewer to.

**"We tried letting non-devs use the codebase before. It was a mess."**
Because they were editing files directly with no guardrails. Frontman is not "give everyone VS Code access." It is a constrained tool that makes specific, reviewable edits through a visual interface. The constraint is the point. A designer cannot refactor your state management through Frontman. They can change the padding. That is the right level of access.

### The Math

A frontend team spends — conservatively — 20% of its sprint capacity on visual tweaks, copy changes, and pixel adjustments. Not because these changes are hard, but because the communication overhead makes them expensive.

Move those changes to the people who request them. The developer time is recovered. The changes ship faster. The designer stops waiting. The PM stops filing tickets for typos. Nobody is blocked on anyone else for changes that take thirty seconds to make and thirty seconds to review.

That is not a productivity hack. That is removing an artificial bottleneck that should never have existed.

Here is what Monday morning looks like after the change: the designer ships three visual fixes before standup. The PM updates the landing page CTA without filing a ticket. The developer's PR queue has zero pixel-adjustment requests. Everyone is working on what they are actually good at. Nobody is blocked on anyone else for a one-character diff.

[Try Frontman](https://frontman.sh) — [one install command](/blog/getting-started/), works with your existing project. Read about [how Frontman keeps every change safe and reviewable](/blog/security/).
