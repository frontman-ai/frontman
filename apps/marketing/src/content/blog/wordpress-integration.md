---
title: 'Frontman Now Supports WordPress'
pubDate: 2026-02-21T05:00:00Z
description: 'Frontman brings AI-powered editing to WordPress. Describe changes in plain English — update themes, edit content, manage settings — and see results live on your site.'
author: 'Itay A'
image: '/blog/post-01-cover.png'
tags: ['announcement', 'wordpress']
---

We started Frontman with a clear idea: put an AI agent inside the app, not the editor. That worked great for JavaScript frameworks like Next.js, Astro, and Vite. But one question kept coming up — what about WordPress?

WordPress powers over 40% of the web. Millions of sites, run by people who range from full-time developers to business owners who just want their site to look right. So we built a WordPress integration.

### How It Works

Install the Frontman plugin, navigate to `/frontman` on your WordPress site, and start talking. The AI agent has full context about your site — your theme, your content, your settings — and can make changes on your behalf.

> Describe what you want. The agent makes it happen.

No code editor required. No terminal. Just a chat interface alongside a live view of your site.

<div style="position:relative;padding-bottom:56.25%;height:0;overflow:hidden;border-radius:8px;margin:2rem 0;">
  <iframe style="position:absolute;top:0;left:0;width:100%;height:100%;border:0;" src="https://www.youtube.com/embed/VIDEO_ID" title="Frontman WordPress Integration Demo" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

### What the Agent Can Do

Frontman for WordPress comes with a full set of tools purpose-built for the platform:

- **Content Management**: Create, edit, and organize posts and pages. Update blocks, reorder content, change copy.
- **Theme Editing**: Read and modify your theme files directly — templates, partials, `theme.json`, `style.css`, `functions.php`. The agent understands WordPress's theme structure.
- **Menu Management**: List, inspect, and update navigation menus and menu items.
- **Site Settings**: Read and update WordPress options. Change the site title, toggle settings, configure plugins.
- **Template Inspection**: Browse block templates and template parts from your active theme.
- **Widget Areas**: List widget areas and update widget configurations.
- **File Operations**: Full filesystem access scoped to your WordPress installation — search, read, and write files.

All of this through natural language. Say "change the site title to Star Wars Cantina" or "update the homepage hero text" and the agent handles the rest.

### How Frontman Compares to Other AI WordPress Plugins

There are already AI plugins in the WordPress ecosystem. Here's how Frontman is different.

**AI Engine** (100k+ installs) and **StifLi Flex MCP** are the closest alternatives. Both expose WordPress tools to AI via MCP and let you manage content through chat. AI Engine is a mature, feature-rich plugin with chatbots, embeddings, content generation, and WooCommerce support. StifLi Flex MCP focuses on being a full MCP server with 117+ tools and connects to external clients like Claude Desktop and ChatGPT.

Frontman takes a fundamentally different approach:

- **Visual feedback loop.** Frontman shows a live preview of your site alongside the chat. When the agent edits a post or modifies your theme, you see the change immediately. Other plugins give you a chat panel in wp-admin — you have to navigate to your site separately to verify what changed.

- **Theme and file editing.** AI Engine and StifLi work through the WordPress API — they can create posts, manage WooCommerce, update options. But they can't open your `style.css` and change a color, or edit a block template HTML file. Frontman runs filesystem tools directly inside the WordPress plugin, so it can read and write theme files, search code with grep, and understand your directory structure.

- **Built for the frontend.** Other AI WordPress plugins started as chatbot/content-generation tools and added site management later. Frontman started as a frontend development tool — it was built to edit what users actually see. That shows in how it handles theme editing, template modifications, and visual changes.

- **Cross-framework.** Frontman isn't WordPress-only. The same agent works with Next.js, Astro, and Vite. If your team works across frameworks, you get one tool that works everywhere.

- **Fully open source.** Frontman's source code — every prompt, every tool definition, every piece of agent logic — is open on [GitHub](https://github.com/frontman-ai/frontman) under Apache 2.0. You can see exactly what the agent does, modify it, or self-host it.

The tradeoff: Frontman is newer and more experimental. AI Engine has 100k+ installs, a Pro tier, WooCommerce tools, embeddings, and years of polish. If you need a production-ready AI content pipeline today, AI Engine is solid. If you want an agent that can see and edit your actual site — theme files, content, and all — that's what Frontman does.

### Architecture

The integration now runs entirely inside the WordPress plugin.

The plugin handles authentication, serves the chat UI, exposes WordPress-specific tools, and provides filesystem tools rooted at your WordPress installation. Tool calls are handled server-side in PHP, with path boundaries enforced to your WordPress root.

### Experimental — and We Need Your Help

This is an early release. The WordPress integration works, but it hasn't been battle-tested across the full range of WordPress setups — different themes, page builders, hosting environments, PHP versions.

We're actively looking for WordPress users and developers to try it and help shape where this integration goes next. If you run into issues, have ideas for new tools, or want better support for specific WordPress patterns, we want that feedback directly from real sites and real workflows.

- **Report issues** on [GitHub](https://github.com/frontman-ai/frontman/issues)
- **Join the conversation** and share feedback
- **Contribute** — the entire codebase is open source under Apache 2.0

### A Note on Production Use

Unlike our JavaScript framework integrations (which are development-only), the WordPress plugin can technically run in production environments. WordPress sites are often edited live, and the plugin respects that workflow.

That said, this is experimental software. If you choose to use it in production, do so with care. We recommend starting in a staging environment, reviewing changes carefully, and keeping backups. The agent writes real code and makes real changes, and it may not always do exactly what you intended — treat it accordingly.

### Getting Started

Getting started is straightforward:

1. Copy the `frontman-wordpress` plugin to `wp-content/plugins/`
2. Activate it from the WordPress admin
3. Navigate to `/frontman` on your site
4. Start chatting

We're excited to bring Frontman to the WordPress ecosystem. This is just the beginning — and with your help, it'll get a lot better.
