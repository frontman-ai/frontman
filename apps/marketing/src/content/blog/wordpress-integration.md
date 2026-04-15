---
title: 'Frontman Now Supports WordPress'
pubDate: 2026-03-31T05:00:00Z
description: 'Frontman brings AI-powered editing to WordPress. Describe changes in plain English, inspect theme files, edit content and settings, then see results live on your site.'
author: 'Itay A'
image: '/blog/frontman-now-supports-wordpress-cover.png'
tags: ['announcement', 'wordpress']
---

We started Frontman with a clear idea: put an AI agent inside the app, not the editor. That worked great for JavaScript frameworks like Next.js, Astro, and Vite. But one question kept coming up: what about WordPress?

WordPress powers over 40% of the web. Millions of sites, run by people who range from full-time developers to business owners who just want their site to look right. So we built a WordPress integration.

### How It Works

Install the Frontman plugin, navigate to `/frontman` on your WordPress site, and start talking. The AI agent has full context about your site: your theme, your content, and your settings. It can make changes on your behalf.

> Describe what you want. The agent handles the supported workflow and shows you the result in the site preview.

No code editor required. No terminal. Just a chat interface alongside a live view of your site.

### What the Agent Can Do

Frontman for WordPress comes with a full set of tools purpose-built for the platform:

- **Content Management**: Create, edit, and organize posts and pages. Update blocks, reorder content, change copy.
- **Managed Theme Editing**: Inspect your live theme files directly, then create a Frontman-managed child theme where the agent can safely create and edit CSS, HTML, and JSON files without touching the original theme. In this first version, that managed-theme workflow targets block themes.
- **Menu Management**: List, inspect, and update navigation menus and menu items.
- **Site Settings**: Read and update WordPress options. Change the site title, toggle settings, configure plugins.
- **Template Inspection**: Browse block templates and template parts from your active theme.
- **Widget Areas**: List widget areas and update widget configurations.
- **File Operations**: Read-only filesystem access scoped to your WordPress installation for searching, reading, and understanding files, plus managed child-theme editing for Frontman-owned theme files.

All of this through natural language. Say "change the site title to Star Wars Cantina" or "update the homepage hero text" and the agent handles the rest.

This managed-theme workflow is for sites running a block-theme parent directly. If another child theme is already active, or if the current theme is not a block theme, Frontman falls back to read-only inspection and manual guidance rather than stacking another child theme on top.

### How Frontman Compares to Other AI WordPress Plugins

There are already AI plugins in the WordPress ecosystem. Here's how Frontman is different.

**AI Engine** (100k+ installs) and **StifLi Flex MCP** are the closest alternatives. Both expose WordPress tools to AI via MCP and let you manage content through chat. AI Engine is a mature, feature-rich plugin with chatbots, embeddings, content generation, and WooCommerce support. StifLi Flex MCP focuses on being a full MCP server with 117+ tools and connects to external clients like Claude Desktop and ChatGPT.

Frontman takes a fundamentally different approach:

- **Visual feedback loop.** Frontman shows a live preview of your site alongside the chat. When the agent edits a post or updates a template, it refreshes the preview so you can verify the result in context. Other plugins give you a chat panel in wp-admin. You have to navigate to your site separately to verify what changed.

- **Theme inspection plus safe child-theme editing.** AI Engine and StifLi work through the WordPress API. They can create posts, manage WooCommerce, and update options. Frontman can inspect theme files directly inside the WordPress plugin, search code with grep, and fork supported theme assets into a Frontman-managed child theme before editing them.

- **Built for the frontend.** Other AI WordPress plugins started as chatbot and content-generation tools, then added site management later. Frontman started as a frontend development tool. It was built to edit what users actually see. That shows in how it handles theme editing, template modifications, and visual changes.

- **Cross-framework.** Frontman isn't WordPress-only. The same agent works with Next.js, Astro, and Vite. If your team works across frameworks, you get one tool that works everywhere.

- **Fully open source.** Frontman's source code, including every prompt, every tool definition, and every piece of agent logic, is open on [GitHub](https://github.com/frontman-ai/frontman). Licenses vary by package and integration, and are declared in the source and release artifacts.

The tradeoff: Frontman is newer and more experimental. AI Engine has 100k+ installs, a Pro tier, WooCommerce tools, embeddings, and years of polish. If you need a production-ready AI content pipeline today, AI Engine is solid. If you want an agent that can see and edit your actual site content while also inspecting the code that renders it and safely editing a managed child theme, that's what Frontman does.

### Architecture

The integration now runs entirely inside the WordPress plugin.

The plugin handles authentication, serves the `/frontman` route, loads the hosted Frontman UI assets, exposes WordPress-specific tools, provides read-only filesystem inspection tools rooted at your WordPress installation, and manages a Frontman-owned child theme for safe CSS, HTML, and JSON edits. Tool calls are handled server-side in PHP, with path boundaries enforced to your WordPress root and the managed theme root.

### This Is Experimental, and We Need Your Help

This is an early release. The WordPress integration works, but it hasn't been battle-tested across the full range of WordPress setups, including different themes, page builders, hosting environments, and PHP versions.

We're actively looking for WordPress users and developers to try it and help shape where this integration goes next. If you run into issues, have ideas for new tools, or want better support for specific WordPress patterns, we want that feedback directly from real sites and real workflows.

- **Report issues** on [GitHub](https://github.com/frontman-ai/frontman/issues)
- **Join the conversation** and share feedback
- **Contribute**: the codebase is open source on GitHub, with licenses declared per package and integration

### A Note on Production Use

Unlike our JavaScript framework integrations (which are development-only), the WordPress plugin can technically run in production environments. WordPress sites are often edited live, and the plugin respects that workflow.

That said, this is experimental software. If you choose to use it in production, do so with care. We recommend starting in a staging environment, reviewing changes carefully, and keeping backups. The agent makes real content, template, and settings changes, and it may not always do exactly what you intended, so treat it accordingly.

### Getting Started

Until Frontman is available in the WordPress marketplace, install the release zip from the [v0.15.0 GitHub release](https://github.com/frontman-ai/frontman/releases/tag/v0.15.0) using the `/wp-admin` Plugins → "Upload Plugin" feature.

We're excited to bring Frontman to the WordPress ecosystem. This is just the beginning, and with your help, it'll get a lot better.
