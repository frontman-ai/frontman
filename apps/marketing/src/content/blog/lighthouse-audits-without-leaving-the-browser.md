---
title: 'Lighthouse Audits Without Leaving the Browser'
pubDate: 2026-02-21T05:00:00Z
description: 'Frontman now runs Google Lighthouse audits as a built-in tool. Your agent sees the scores, reads the issues, and fixes them — all inside the browser you are already working in.'
author: 'Frontman Team'
image: '/blog/lighthouse-audits-cover.png'
tags: ['performance', 'ai', 'developer-tools']
---

You run a Lighthouse audit in Chrome DevTools. You get a wall of scores and recommendations. You copy the URL of your failing resource, switch to your editor, search for the right file, try to map the Lighthouse recommendation to an actual code change, switch back to the browser, re-run the audit, and check if the score moved. Repeat for each issue.

This is the standard workflow. It works. It is also entirely manual, context-destroying, and about five steps longer than it needs to be.

Frontman now runs Lighthouse audits as a built-in agent tool. Your agent launches Chrome, audits the URL you are looking at, reads the scores, and starts fixing the issues — all inside the browser you are already working in.

<!-- VIDEO_PLACEHOLDER: Demo video showing Frontman running a Lighthouse audit and fixing issues in a single session -->

### How It Works

When your agent calls the Lighthouse tool, here is what happens under the hood:

1. **Chrome launches headless** — no manual setup, no global installs. Lighthouse and chrome-launcher are bundled as dependencies.
2. **All four categories run** — Performance, Accessibility, Best Practices, and SEO. Every audit, every time.
3. **Scores come back as 0–100** with the top three failing audits per category, including what failed and why.
4. **The agent reads the results** and starts editing your code to fix them.

The agent does not need you to copy scores from one tab and paste them into another. It ran the audit. It has the results. It can act on them.

### What the Agent Sees

When the audit completes, the agent gets structured data like this:

```text
Performance: 62/100
  - Largest Contentful Paint element (7,240 ms)
  - Eliminate render-blocking resources (saves 1,200 ms)
  - Properly size images (saves 340 KiB)

Accessibility: 88/100
  - Image elements do not have [alt] attributes
  - Links do not have a discernible name
  - Background and foreground colors do not have a sufficient contrast ratio

Best Practices: 92/100
  - Uses deprecated APIs
  - Browser errors were logged to the console

SEO: 78/100
  - Document does not have a meta description
  - Links are not crawlable
  - Image elements do not have [alt] attributes
```

The agent reads "Largest Contentful Paint element" and knows exactly which element to investigate. It traces the element back through your component tree, finds the image that is 3 MB when it should be 200 KB, adds `next/image` with proper `width` and `height` attributes, and the LCP drops from 7.2 seconds to 1.8 seconds.

No tab switching. No copy-pasting issue descriptions. No translating Lighthouse jargon into code changes yourself.

### Why This Matters More Than You Think

Running Lighthouse from the terminal is possible. Running it from a CI pipeline is common. But neither of those gives the agent what it needs: the audit results _and_ the ability to fix them in the same session.

Here is the standard coding-agent workflow for performance optimization:

```text
You: "Improve the Lighthouse score on the homepage"
Agent: *opens the source file, looks at the code, makes educated guesses*
       *adds lazy loading to some images*
       *defers a script tag*
You: *opens Chrome DevTools, runs Lighthouse manually*
You: "Performance went from 62 to 68. The LCP image is still too large."
Agent: *reads your description, tries to find the image*
You: *runs Lighthouse again*
You: "Better. Now accessibility is failing on contrast ratios."
Agent: *asks which elements*
You: *copies the audit output, pastes it into the chat*
```

Five rounds. You are the human bridge between Lighthouse and the agent. You run the audit, read the results, translate them into text, and feed them to the agent one issue at a time.

Here is Frontman:

```text
You: "Run a Lighthouse audit on this page and fix the top issues"
Frontman: *launches Chrome, runs full audit*
         *reads: Performance 62, LCP element 7.2s, render-blocking resources*
         *optimizes the hero image, adds lazy loading, defers non-critical JS*
         *re-runs audit: Performance 89*
         *reads: Accessibility 88, missing alt attributes*
         *adds alt text to 4 images*
         *re-runs audit: Accessibility 100*
```

One prompt. The agent runs the audit, reads the results, makes the fixes, and verifies the improvement by running the audit again. You are not the middleware. The agent is.

### Mobile and Desktop

Frontman reads the `device_emulation` context from your current session. If you are viewing the page in mobile mode, the agent passes `preset: "mobile"` to Lighthouse automatically. You do not need to specify it. The audit matches what you are looking at.

This matters because mobile and desktop Lighthouse scores are often different. A page that scores 95 on desktop might score 62 on mobile because of an unoptimized hero image that only appears on small viewports, or a render-blocking script that desktop hardware chews through but mobile throttling exposes.

The agent audits what you are seeing. Not a default it picked.

### The Shift

Performance optimization has always been a feedback loop: measure, identify the issue, fix it, measure again. The problem was never the fixing — it was the measuring, and the translation layer between measurement and action.

When the agent can run Lighthouse itself, that translation layer disappears. The measurement _is_ the context. The agent reads the failing audit, traces it to the source, makes the change, and verifies the improvement — all in one continuous action.

Your performance scores stop being a report you read and start being a problem the agent solves.

[Try Frontman](https://frontman.sh) — [one install command](/blog/getting-started/), works with your existing project. Read about [why coding agents are blind to your UI](/blog/ai-coding-agents-blind-to-ui/), see [how Frontman compares to Cursor and Claude Code](/blog/frontman-vs-cursor-vs-claude-code/), or read the full [Frontman vs Cursor](/vs/cursor/) comparison.
