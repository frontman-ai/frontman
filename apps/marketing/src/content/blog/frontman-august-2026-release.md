---
title: 'Frontman AI Update: Plan, Execute, and Review in One Workflow'
seoTitle: 'Frontman AI Update: Plans, Diffs, and Annotations'
pubDate: 2026-08-27T00:00:00Z
description: 'The August 2026 Frontman AI update adds one-click plan execution, file-change diffs, linked UI annotations, and stronger task recovery.'
author: 'Danni Friedland'
image: '/blog/frontman-august-2026-release-cover.png'
imageAlt: 'Frontman logo and the title Frontman AI Update: Plan, Execute, and Review in One Workflow on a dark grid background'
articleSection: 'Product Announcement'
tags: ['announcement', 'frontend-agent', 'browser-aware-ai', 'mcp']
---

Frontman can now take one visual task from a selected browser element to a reviewable file diff without losing context between steps.

The August 2026 Frontman AI update adds one-click plan execution, a new **Changes** view, and annotations that link back to the live preview. It also makes queued and restored tasks easier to follow.

The release shipped on August 27, 2026. It includes breaking contracts for browser tools, so several packages have major version bumps. Frontman does not have one product-wide version.

## What's New in Frontman

| New capability | What it changes |
| --- | --- |
| **Execute plan** | Send a completed plan to the executor without starting another conversation |
| **Changes view** | Inspect file edits as diffs beside the live application |
| **Linked annotations** | Jump from a sent message to the exact annotated element in the preview |
| **Stronger task recovery** | Restore tool calls and todo plans when you reopen a task |
| **Clearer message queue** | See submitted prompts before server acceptance and keep model changes in separate turns |

Together, these changes turn Frontman from a browser-aware prompt surface into a more complete review loop. The browser stays next to the work from the first instruction to the final diff.

## One Continuous Frontend Agent Workflow

Frontman starts with evidence from the running application: the selected element, current browser state, component context, and source location. That [runtime context](/blog/runtime-context-gap/) helps the agent identify what the user means before it searches the codebase.

This release carries that evidence through more of the task:

```text
Select an element
-> describe the result
-> review the plan
-> execute the plan
-> inspect the file diffs
-> verify the result in the preview
```

Consider a pricing card with the wrong spacing on mobile. You annotate the card and ask Frontman to use the existing spacing scale. The planner identifies the component, affected breakpoint, and expected token. You review that plan and select **Execute plan**.

After the edit, **Changes** shows which file changed and whether the agent used the expected token. Select the original annotation chip to bring the pricing card back into view. The task stays connected to both forms of evidence: code and pixels.

That is the job of a [browser-aware AI coding agent](/blog/what-are-browser-aware-ai-coding-tools/). It does not merely open a browser. It connects a visible result to the source change that produced it.

## Execute a Plan Without Rebuilding Context

The planner can inspect a request and produce ordered implementation steps before source edits begin. Frontman now displays an **Execute plan** action when the planner finishes.

The action sends the plan to the executor in the same conversation. You do not need to paste the plan into a new prompt or explain the selected elements again.

This preserves a useful approval point. Read the plan before execution, especially when the selected element belongs to a shared component or design system.

## Review AI File Changes as Diffs

A correct preview is not proof of a safe implementation. The page can look right while the code bypasses a design token, changes a shared component, or touches an unrelated file.

Frontman's new **Changes** view reports edits from supported file tools and displays the previous and updated content as a diff. You can inspect implementation details without leaving the browser workflow.

The preview and diff answer different questions:

- **Preview:** Does the result match the visual request?
- **Diff:** Did the agent make the correct source change?

This does not replace Git, repository tests, or engineering review. It makes the first review available at the point where the change happens.

## Link Every Annotation Back to the UI

Annotations already give Frontman a bounded DOM region and source context. They replace vague prompts such as "fix the second card" with a direct reference to a rendered element.

Annotation chips in sent messages are now interactive. Select a chip to highlight its element and scroll it into view. Select the chip again to clear the highlight.

This matters after a long agent turn. Earlier instructions no longer become detached references inside chat history.

## Why Some Packages Have Major Version Bumps

This is not a product-wide "Frontman 4" release. Packages in the repository use independent versions.

| Package | Released version | Reason |
| --- | ---: | --- |
| `@frontman-ai/frontman-wordpress` | `4.0.0` | Ships the updated browser integration |
| `@frontman-ai/frontman-client` | `3.0.0` | Adopts breaking browser MCP contracts |
| `@frontman-ai/frontman-protocol` | `3.0.0` | Defines the new MCP and message contracts |
| `@frontman-ai/client` | `1.1.0` | Adds the new user workflow |
| `@frontman-ai/astro` | `2.0.3` | Updates integration dependencies |
| `@frontman-ai/nextjs` | `1.0.6` | Updates compatibility and installation checks |
| `@frontman-ai/vite` | `1.0.6` | Updates integration dependencies |

Browser tool discovery, tool listing, and tool calls now use MCP 2026-07-28. Prompt requests also require a client-generated `_meta["frontman.dev/messageId"]` value. The server uses this value during live updates, queued execution, and history replay.

Older clients and custom integrations that use the previous contracts are incompatible. The [`v4.0.0` GitHub tag](https://github.com/frontman-ai/frontman/releases/tag/v4.0.0) identifies the repository release bundle, not every package in it.

## More Reliable Long-Running Tasks

The release also improves the less visible parts of agent work:

- Submitted prompts remain visible while they wait for server acceptance.
- Queued prompts that use different models remain separate agent turns.
- Todo plans return when you reopen a task and disappear after completion.
- Tool calls return with restored task history.
- One active connection owns a task channel at a time.
- NVIDIA models run through NVIDIA NIM again.
- Screenshot failures include guidance when the browser cannot decode an image.

The tagged release adds [DNS-rebinding protection to WebFetch](https://github.com/frontman-ai/frontman/pull/1543) and keeps malformed tool arguments out of diagnostic reports.

Frontman can inspect browser state and change local source files. Teams need to inspect the code that crosses those boundaries. The browser client and JavaScript integrations use Apache-2.0, the WordPress plugin uses GPL-2.0-or-later, and Frontman Server uses AGPL-3.0-only with AI Supplementary Terms. Read the [Frontman security model](/blog/security/) before you connect an authenticated application or sensitive development data.

## Where Frontman Fits

Frontman is a [frontend agent](/blog/frontend-agent/) for work whose acceptance criteria live in the rendered application. Good tasks include spacing, typography, responsive layout, copy, presentational components, and visual QA.

Use a general coding agent or IDE-centered workflow for backend changes, data models, dependency migrations, and broad refactors. Browser context does not provide enough evidence to approve authorization, persistence, or business-rule changes.

## Update Frontman

Next.js now requires version 15.5.x or 16.x. Frontman's React packages require React 19.2.8 or newer. Review these requirements before you update.

For Next.js, Astro, or Vite, update the relevant `@frontman-ai/*` package with your current package manager. Then restart the development server and open `/frontman` to verify the installation.

For WordPress, install the update through the normal plugin update flow in wp-admin.

Read the [complete release notes](https://github.com/frontman-ai/frontman/releases/tag/v4.0.0), then use the [Frontman installation guide](/docs/installation/) for framework-specific steps. For Next.js, Astro, or Vite, start with one visible task: create a plan, execute it, and inspect **Changes** before you keep the edit.
