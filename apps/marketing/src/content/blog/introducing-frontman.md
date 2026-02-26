---
title: 'Frontman: The AI Agent That Sees Your Browser'
pubDate: 2026-02-18T05:00:00Z
description: 'Frontman is the open-source AI agent that hooks into your framework, sees your live DOM, and edits your actual source code. No guessing, no blind edits.'
author: 'Frontman Team'
image: '/blog/introducing-frontman-cover.png'
tags: ['announcement', 'open-source']
---

You tell Cursor to fix the spacing on your hero section. It reads the file, picks a Tailwind class that looks right, and saves. You switch to the browser. Wrong element. You switch back, add more context — the exact file path, the line number, maybe a hint about the component tree. The agent tries again. You switch to the browser again. Closer. One more round.

Three iterations and six tab switches to change a padding value. Your agent had full access to the source code the entire time. It read every file. It just could not _see_ the page.

### Why AI Agents Cannot See Your Frontend

Claude is not stupid. Cursor is not broken. The agent genuinely cannot see what your page looks like. It reads source files. It reads terminal output. It reads build errors. None of that tells it what `p-4 md:p-8` resolves to at your current viewport width, or which of three nested `div`s with padding classes is the one you are staring at in the browser.

Every coding agent on the market today is _blind to the rendered UI_. They edit files and hope the visual result matches your intent. For backend code, this is fine. For frontend work, hope is not a methodology.

**Other agents guess. Frontman sees.**

Frontman connects to both your dev server _and_ your browser. It has direct access to the live DOM, computed styles, your component tree, your routes, and your compilation errors. When you click an element and describe a change, Frontman knows exactly which file and which line to edit — because it can verify the result immediately.

### What That Looks Like

You click a button in the browser. You type "make the font size 18px." This is what happens:

```diff
// src/components/Hero.tsx
- <button className="text-sm px-4 py-2 bg-blue-600 text-white rounded">
+ <button className="text-lg px-4 py-2 bg-blue-600 text-white rounded">
    Get Started
  </button>
```

The file saves. Hot-reload fires. The button updates in the browser. One action, one result, zero tab switches. The diff is in your working tree, ready for `git add`.

**Frontman sees.** It does not grep for class names and guess which one to change. It reads the computed `font-size` off the live element, traces it through the component tree to the source file and line, and makes the edit. That is a fundamentally different operation from reading files and inferring what the UI probably looks like.

### Who Actually Needs This

If you have ever burned fifteen minutes of agent context trying to describe which `div` you mean, Frontman is for you. If you have ever reviewed a PR that was one line of CSS wrapped in three days of Jira comments, Frontman is for your team. If you have a designer who files tickets for spacing changes and waits a sprint to see them land, Frontman is for them — they click the element, describe the change, and the source file updates. No IDE. No file paths. No waiting.

### Common Objections

**"My agent can read files and edit them directly. That's basically the same thing."**
It is not. Your agent reads the _source_. Frontman reads the _rendered output_. The source says `className="p-4 md:p-8 lg:p-12"`. The rendered output says "this element has 32px of padding at the current viewport." The source has three nested divs with padding. The rendered output shows you which one the user is actually pointing at. Your agent is working from a blueprint. Frontman is standing in the room.

**"What about v0 or Bolt? They generate full UIs."**
They do. From scratch. In a sandbox. Frontman works with _your existing codebase_, your component library, your design tokens, your file conventions. It reads your `agents.md`. It follows your patterns. Generated UIs are demos. Frontman edits production code.

**"AI-generated code changes are risky."**
Every change Frontman makes is a file edit in your working directory. It shows up in `git diff`. It goes through your normal PR review. If it is wrong, `git checkout` fixes it. This is not riskier than accepting a diff from Cursor or Claude Code — it is the same workflow you already trust.

### The Better World

A designer opens the app in their browser, clicks the hero section, types "reduce the top padding on mobile," and the source file updates. A developer reviews a clean one-line diff in the PR. Nobody filed a ticket. Nobody context-switched. Nobody burned twenty minutes of agent context describing which element they meant.

That is not a fantasy. That is Frontman running on localhost.

**Frontman sees.** [Get started in under 5 minutes](/blog/getting-started/). Open source, Apache 2.0, free during beta. Want to understand [how it compares to Cursor and Claude Code](/blog/frontman-vs-cursor-vs-claude-code/)? See the full [Frontman vs Cursor](/vs/cursor/) comparison.
