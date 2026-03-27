---
title: Introduction
description: Frontman is an open-source AI coding agent that lives in your browser. Chat with it, point at elements, and watch it edit your source code in real time. 
---

Frontman is an open-source AI coding agent that runs inside your development browser. You chat with it in natural language or point at elements on your page, and it edits your actual source files — with instant hot reload so you see changes immediately.

:::tip[The 30-second mental model]
You describe a change → the agent takes a screenshot of your running app → reads relevant source code → makes edits → your dev server hot-reloads → you see the result. No copy-pasting, no context-switching, no "refresh and check."
:::

## Who uses Frontman?

**Developers** set up Frontman in their project (a one-line integration for Astro, Next.js, or Vite) and use it alongside their existing editor. The agent sees both the rendered page and the source code, so it makes precise, file-level edits that compile and render correctly.

**Designers, PMs, and non-technical teammates** use the chat UI to make changes directly. Select an element, describe what you want ("make this button larger," "change the heading text," "swap the layout to two columns"), and the agent handles the code. No IDE required.

## Where to go from here

### Setting up Frontman

Start here if Frontman isn't running in your project yet.

| Framework | Install command | Docs |
|-----------|----------------|------|
| **Astro** | `astro add @frontman-ai/astro` | [Astro integration →](/docs/integrations/astro/) |
| **Next.js** | `npx @frontman-ai/nextjs init` | [Next.js integration →](/docs/integrations/nextjs/) |
| **Vite** | `npm install @frontman-ai/vite` | [Vite integration →](/docs/integrations/vite/) |
| **WordPress** | Standalone binary (beta) | [WordPress setup →](/docs/integrations/wordpress/) |

Then continue with:

1. **[API Keys & Providers](/docs/api-keys/)** — Configure your AI model (free tier, bring-your-own-key, or OAuth)


### Learning to use Frontman

Already running? Learn how to get the most out of it.

- **[How the Agent Works](/docs/using/how-the-agent-works/)** — Understand the screenshot → read → edit loop
- **[Sending Prompts](/docs/using/sending-prompts/)** — Write effective prompts with good examples
- **[Annotations](/docs/using/annotations/)** — Point at elements instead of describing them
- **[Prompt Strategies](/docs/using/prompt-strategies/)** — Patterns for getting better results over time

### Deep dives

For developers who want framework-specific detail or technical reference.

- **[Integrations](/docs/integrations/astro/)** — Framework-specific guides (Astro, Next.js, Vite, WordPress)
- **[Reference](/docs/reference/configuration/)** — Configuration options, environment variables, architecture, troubleshooting
