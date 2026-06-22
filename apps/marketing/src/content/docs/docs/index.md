---
title: Frontman Docs
description: Frontman documentation for installation, framework integrations, API keys, usage guides, troubleshooting, and self-hosting.
---

Frontman is an open-source AI coding agent that runs inside your development browser. You chat with it in natural language or point at elements on your page, and it edits your actual source files — with instant hot reload so you see changes immediately.

:::tip[The 30-second mental model]
You describe a change → the agent takes a screenshot of your running app → reads relevant source code → makes edits → your dev server hot-reloads → you see the result. No copy-pasting, no context-switching, no "refresh and check."
:::

## Who uses Frontman?

**Developers** set up Frontman in their project (a one-line integration for Astro, Next.js, or Vite) or install the WordPress plugin. The agent sees the rendered experience plus the underlying source or CMS context, so it makes precise edits you can review.

**Designers, PMs, and non-technical teammates** use the chat UI to make changes directly. Select an element, describe what you want ("make this button larger," "change the heading text," "swap the layout to two columns"), and the agent handles the code. No IDE required.

## Where to go from here

### Setting up Frontman

Start here if Frontman isn't running in your project yet.

| Framework | Install command | Docs |
|-----------|----------------|------|
| **Astro** | `astro add @frontman-ai/astro` | [Astro integration →](/docs/integrations/astro/) |
| **Next.js** | `npx @frontman-ai/nextjs install` | [Next.js integration →](/docs/integrations/nextjs/) |
| **Vite** | `npx @frontman-ai/vite install` | [Vite integration →](/docs/integrations/vite/) |
| **WordPress** | [WordPress Plugin Directory](https://wordpress.org/plugins/frontman-agentic-ai-editor/) (beta) | [WordPress setup →](/docs/integrations/wordpress/) |

Then continue with:

1. **[API Keys & Providers](/docs/api-keys/)** — Configure your AI model with OAuth or a provider API key


### Learning to use Frontman

Already running? Learn how to get the most out of it.

- **[How the Agent Works](/docs/using/how-the-agent-works/)** — Understand the screenshot → read → edit loop
- **[Sending Prompts](/docs/using/sending-prompts/)** — Write effective prompts with good examples
- **[Annotations](/docs/using/annotations/)** — Point at elements instead of describing them
- **[Prompt Strategies](/docs/using/prompt-strategies/)** — Patterns for getting better results over time
- **[Best Frontend Coding Agent guide](/blog/best-frontend-coding-agent/)** — Compare tools if your team wants to build frontend with AI

### Deep dives

For developers who want framework-specific detail or technical reference.

- **[Integrations](/docs/integrations/astro/)** — Framework-specific guides (Astro, Next.js, Vite, WordPress)
- **[Reference](/docs/reference/)** — Configuration options, environment variables, architecture, troubleshooting
