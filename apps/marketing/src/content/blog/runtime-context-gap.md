---
title: 'Runtime Context Gap in AI Coding Tools'
pubDate: 2026-02-20T05:00:00Z
description: 'A technical taxonomy of static, process, browser, framework, and verification context, with examples of how coding agents can collect each layer.'
author: 'Danni Friedland'
articleSection: 'Technical Explainer'
image: '/blog/runtime-context-gap-cover.png'
imageAlt: 'Runtime Context Gap in AI Coding Tools cover'
tags: ['ai', 'developer-tools']
updatedDate: 2026-07-30T00:00:00Z
---

The runtime context gap is not “AI cannot see a browser.” Modern coding agents can receive browser data through built-in integrations, automation libraries, or MCP servers. The more precise definition is:

> A runtime context gap exists when evidence needed to decide or verify a code change is produced only while the system runs, but that evidence is absent from the agent's working context.

This definition is task-specific. Source text may be sufficient to rename a function. It is insufficient to prove which CSS rule wins at a particular viewport or which middleware handled a request.

## A Five-Layer Context Taxonomy

| Layer                | Typical evidence                                              | Question it answers                    |
| -------------------- | ------------------------------------------------------------- | -------------------------------------- |
| Static project       | source, config, types, dependency graph                       | What could the program do?             |
| Process runtime      | logs, environment, loaded modules, routes, requests           | What did this running process do?      |
| Browser document     | DOM, accessibility tree, computed styles, geometry, network   | What did this page render and request? |
| Framework provenance | component tree, props, hydration boundaries, source locations | Which framework construct produced it? |
| Verification         | tests, traces, screenshots, before/after runtime values       | Did the change satisfy the criterion?  |

Tools differ less by whether they are “runtime-aware” than by which layers they collect, how fresh that evidence is, and whether they correlate layers reliably.

## Layer 1: Static Project Context

Static context includes source files, build configuration, type information, lockfiles, and relationships an agent can infer without running the application. This is the strongest layer for API changes, refactors, and repository-wide consistency checks.

Static context can show that a component contains `padding: var(--space-4)`. It cannot establish the final value of that custom property in a particular document state, whether another rule overrides the declaration, or the element's resulting geometry.

The gap begins only when one of those facts matters to the task.

## Layer 2: Process Runtime Context

Process context is evidence from a running development server, application server, worker, or test process:

- emitted logs and stack traces;
- environment-dependent configuration;
- observed requests and responses;
- loaded or transformed modules;
- route and middleware behavior;
- hot-update events and build errors.

Example: source inspection may show several possible request handlers. A request trace or server log identifies which handler ran with the current host, flags, and middleware order. That is observed behavior, not a prediction from files.

Development servers also maintain runtime state. [Vite's HMR API](https://vite.dev/guide/api-hmr) documents update boundaries, invalidation, and client/server HMR events. Reading a source import graph is related to, but not identical with, observing how the active dev server handles an update.

## Layer 3: Browser Document Context

Browser context includes data exposed by the live page and browser tooling:

- rendered DOM and accessibility structure;
- computed CSS and matched rules;
- element bounding boxes and viewport state;
- console messages and exceptions;
- network requests, responses, and timing;
- focus, selection, scroll, and interaction state.

These are distinct evidence types. A screenshot can prove visible output but loses DOM identity. A DOM snapshot gives structure but may omit interaction history. Computed styles show resolved values but not necessarily the maintainable source edit.

[Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) documents browser automation, DOM snapshots, console and network inspection, screenshots, emulation, and performance traces. [Claude Code's Chrome integration](https://code.claude.com/docs/en/chrome) documents a similar class of browser tasks. These integrations close parts of the browser gap; they do not automatically close every other layer.

## Layer 4: Framework Provenance

The browser owns DOM nodes. A framework owns higher-level concepts such as components, props, state, server/client boundaries, or hydration units. Mapping between them is framework-specific.

[React Developer Tools](https://react.dev/learn/react-developer-tools), for example, provides Components and Profiler panels to inspect React components, props, state, and performance. That capability exists because a component tree is not equivalent to an HTML DOM tree.

For coding agents, useful provenance can include:

- component display name and ownership chain;
- source file and line associated with a rendered element;
- props or state relevant to the selected output;
- whether a component or token is shared;
- framework diagnostics from the development server.

This is where framework integrations can add information that generic browser control does not document. Depth varies by framework, build mode, and tool; “has DOM access” should not be used as a proxy for source provenance.

## Layer 5: Verification Context

Collection before an edit helps choose a change. Collection after an edit determines whether it worked.

Verification should match the acceptance criterion:

- For layout: compare computed values, geometry, and relevant viewports.
- For behavior: replay the user flow and inspect resulting state.
- For network bugs: compare requests, responses, and console/server errors.
- For performance: collect a trace under controlled conditions.
- For code health: run tests, type checks, lint, and inspect the diff.

“The file changed” is not runtime verification. “The page refreshed” is not proof that the target state is correct. Conversely, “the screenshot looks right” does not prove shared components, tests, or accessibility remain correct.

## Three Integration Patterns

### Browser Automation

An agent drives a browser through an extension or automation protocol. This is portable and effective for navigation, user flows, screenshots, DOM inspection, and browser diagnostics. It may require the agent to discover the target and correlate browser evidence with source.

### DevTools or MCP Bridge

A server exposes selected browser or process capabilities as structured tools. MCP standardizes how an agent invokes those tools, not the depth or accuracy of the underlying evidence. A browser MCP server and a framework MCP server can expose very different context.

### Framework Integration

A plugin or middleware layer gathers framework-specific metadata and may connect runtime entities to source. This can improve provenance but costs implementation effort, framework coverage, and compatibility maintenance.

Frontman combines browser tools with local framework integrations; see the [Frontman repository](https://github.com/frontman-ai/frontman) for the implementation and license boundaries. Other tools choose different combinations. [Browser-aware AI tools](/blog/browser-aware-ai-tools-2026/) compares products, while the [UI-context checklist](/blog/ai-coding-agents-blind-to-ui/) explains how to evaluate their evidence.

## Failure Modes to Test

Runtime access can still produce wrong conclusions:

- **Stale state:** evidence was captured before the relevant interaction or update.
- **Wrong target:** the agent inspected a visually similar node or component instance.
- **Missing provenance:** it found a DOM value but guessed the controlling source.
- **Unrepresentative environment:** development flags, data, fonts, or viewport differ from the failing case.
- **Shallow verification:** one state improved while another regressed.
- **Excessive access:** browser or process data entered agent context without appropriate controls.

Runtime-aware systems should make evidence and uncertainty visible, not merely add more opaque context.

## The Architectural Takeaway

No single context layer is the truth for every task. Source describes intent and possible behavior. Runtime instruments provide observations. Framework metadata provides provenance. Tests and review decide whether a proposed change is acceptable.

Better coding-agent architecture connects those layers without pretending observation replaces engineering judgment. For workflow selection across browser, IDE, and terminal tools, read [Frontman vs Cursor vs Claude Code](/blog/frontman-vs-cursor-vs-claude-code/). For hands-on setup, see the [Next.js runtime context tutorial](/blog/tutorial-nextjs-runtime-context/).
