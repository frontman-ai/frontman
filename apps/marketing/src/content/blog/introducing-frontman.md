---
title: 'Introducing Frontman: AI That Sees Your UI'
seoTitle: 'Browser-Aware AI Coding Agent'
pubDate: 2026-02-18T05:00:00Z
description: 'Why we built Frontman, what category it belongs to, where browser-aware editing helps, and where a browser-first workflow is the wrong tool.'
author: 'Danni Friedland'
image: '/blog/introducing-frontman-cover.png'
imageAlt: 'Introducing Frontman browser-aware AI coding agent'
articleSection: 'Product Announcement'
tags: ['ai', 'frontend', 'developer-tools']
updatedDate: 2026-07-30T00:00:00Z
---

Frontman began with a narrow observation: frontend changes are often described in the browser but implemented somewhere else.

A reviewer points at a rendered element. An engineer translates that observation into a component, source file, style rule, and testable change. General-purpose coding agents improved the file-editing half of that workflow, but the translation step remained manual. We built Frontman to make that browser-to-source path explicit.

## The Product Thesis

Frontman is a browser-first coding agent for existing web applications. It connects three kinds of evidence:

- the rendered page and current browser state;
- framework and component context supplied by a local integration;
- the source files that produce the selected UI.

The interaction starts from an element in the running application rather than a file tree or terminal prompt. Frontman can inspect browser evidence, propose source edits, and show the result through the application's normal development feedback loop.

That makes Frontman one example of [browser-aware AI](/blog/what-are-browser-aware-ai-coding-tools/) and, more specifically, a [frontend agent](/blog/frontend-agent/). It is not a new model category. It is an agent architecture and interaction model built around runtime UI context.

## Why Build a Separate Browser-First Tool?

Browser integrations now exist for general coding agents. [Claude Code can connect to Chrome](https://code.claude.com/docs/en/chrome), [Cursor documents browser tools](https://cursor.com/docs/agent/tools/browser), and [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) exposes browser debugging and automation to multiple clients. Those are meaningful improvements; “coding agents cannot use browsers” is no longer accurate.

Frontman's bet is narrower: direct, user-led element selection plus project-specific source context deserves a primary workflow, not only an optional tool call. Browser automation commonly starts with an agent deciding where to navigate and what to inspect. Frontman starts with a person identifying the exact rendered target, then adds component and source evidence around that target.

Neither interaction model dominates every task. Agent-led browsing works well for scripted flows and autonomous verification. User-led selection works well when a reviewer already knows which visual result is wrong.

## What Frontman Is For

Frontman is designed for changes whose acceptance criteria live in the rendered application:

- spacing, typography, color, and responsive layout;
- copy and presentational component changes;
- visual QA findings tied to a specific element or state;
- tracing a rendered element back to its source;
- iterating while preserving a normal code-diff review process.

Designers and product managers can initiate such changes without first learning the repository layout. Engineers can use the same context to reduce source-to-screen investigation. In both cases, the output remains code that should pass the project's usual review and checks.

## What Frontman Is Not For

Frontman is not intended to replace a general-purpose coding agent, IDE, test suite, or engineer.

Use terminal- or IDE-centered tools for backend changes, broad refactors, dependency migrations, data modeling, CI work, and tasks where shell output or codebase-wide reasoning is primary. Use design tools for open-ended visual exploration before an implementation exists. Use dedicated browser automation or test frameworks when repeatable end-to-end coverage is the deliverable.

Frontman can touch source outside styling, but capability is not the same as workflow fit. If a request changes authorization, persistence, business rules, or public interfaces, browser selection provides little of the evidence needed to judge correctness.

## Honest Tradeoffs

### Runtime Context Costs Setup

Frontman needs a running application and a supported local integration. A file-only task can start without either. Framework-specific context can provide better provenance, but it also creates integration and maintenance work that a framework-agnostic agent avoids.

### Visual Feedback Can Encourage Shallow Fixes

A change that looks correct may still bypass a token, modify a shared component unintentionally, or fail at another breakpoint. Frontman shows runtime evidence; it does not make engineering judgment automatic. Review the diff and blast radius.

### Browser Access Expands the Trust Boundary

Authenticated pages and browser state can contain sensitive data. Teams should use development data, limit accessible origins, understand model-provider data handling, and retain approval gates. See [Frontman's security model](/blog/security/) before connecting a project.

### Browser-First Is Not Always Faster

If an engineer already knows the file and needs a mechanical refactor, opening the rendered application adds no value. Frontman earns its place when target identification or visual verification is part of the hard problem.

## Source Availability and Boundaries

Frontman's code and license boundaries are visible in the [Frontman GitHub repository](https://github.com/frontman-ai/frontman). The browser client and JavaScript integrations use Apache-2.0, the WordPress plugin uses GPL-2.0-or-later, and Frontman Server uses AGPL-3.0-only with AI Supplementary Terms. “Source-available” describes the combined product more accurately than calling every part open source.

That split is part of the product boundary: local integrations own project access and runtime context, while the server orchestrates the agent workflow. Teams evaluating self-hosting should review both the licenses and the data path rather than relying on a single label.

## Where the Category Goes

Browser access is becoming a standard agent capability. Differentiation will move toward context quality: exact state reproduction, element identity, framework provenance, source mapping, safe edit scope, and verification.

That is the category Frontman is built around. The detailed technical model is in [the runtime context gap](/blog/runtime-context-gap/). The practical buying question is covered in [Frontman vs Cursor vs Claude Code](/blog/frontman-vs-cursor-vs-claude-code/).

[Try Frontman](https://frontman.sh) on an existing project, with the same requirement we recommend for every coding agent: inspect and understand the diff before merging it.
