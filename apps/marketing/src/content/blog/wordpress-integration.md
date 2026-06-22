---
title: 'AI Editing for WordPress'
seoTitle: 'AI WordPress Editor Plugin'
pubDate: 2026-03-31T05:00:00Z
description: 'Use Frontman as an AI WordPress editor plugin for content, Elementor pages, menus, templates, widgets, settings, and live site preview.'
author: 'Itay A'
image: '/blog/frontman-now-supports-wordpress-cover.png'
tags: ['announcement', 'wordpress']
updatedDate: 2026-06-17T00:00:00Z
---

We started Frontman with a clear idea: put an AI agent inside the app, not the editor. That worked great for JavaScript frameworks like Next.js, Astro, and Vite. But one question kept coming up: what about WordPress?

WordPress powers over 40% of the web. Millions of sites, run by people who range from full-time developers to business owners who just want their site to look right. So we built a WordPress integration.

**Quick answer:** [Frontman for WordPress](/wordpress/) is an AI WordPress editor plugin that lets you describe changes in plain English, edit WordPress content and Elementor pages, and verify the result in a live site preview.

## How It Works

Install the Frontman plugin, navigate to `/frontman` on your WordPress site, and start talking. The AI agent can work with your content, Elementor pages, menus, templates, widgets, and settings. It can make changes on your behalf.

> Describe what you want. The agent handles the supported workflow and shows you the result in the site preview.

No code editor required. No terminal. Just a chat interface alongside a live view of your site.

## What the Agent Can Do

Frontman for WordPress comes with a full set of tools purpose-built for the platform:

- **Content Management**: Create, edit, and organize posts and pages. Update blocks, reorder content, change copy.
- **Elementor Editing**: Update Elementor pages with Elementor-aware tools and version-aware edits.
- **Menu Management**: List, inspect, and update navigation menus and menu items.
- **Site Settings**: Read and update WordPress options. Change the site title, toggle settings, configure plugins.
- **Template Inspection**: Browse block templates and template parts from your active theme.
- **Widget Areas**: List widget areas and update widget configurations.

All of this through natural language. Say "change the site title to Star Wars Cantina" or "update the homepage hero text" and the agent handles the rest.

## How Frontman Compares to Other AI WordPress Plugins

There are already AI plugins in the WordPress ecosystem. Here's how Frontman is different.

**AI Engine** (100k+ installs) and **StifLi Flex MCP** are the closest alternatives. Both expose WordPress tools to AI via MCP and let you manage content through chat. AI Engine is a mature, feature-rich plugin with chatbots, embeddings, content generation, and WooCommerce support. StifLi Flex MCP focuses on being a full MCP server with 117+ tools and connects to external clients like Claude Desktop and ChatGPT.

Frontman takes a fundamentally different approach:

- **Visual feedback loop.** Frontman shows a live preview of your site alongside the chat. When the agent edits a post or updates a template, it refreshes the preview so you can verify the result in context. Other plugins give you a chat panel in wp-admin. You have to navigate to your site separately to verify what changed.

- **Elementor and WordPress-native workflows.** AI Engine and StifLi expose broad WordPress tools. Frontman focuses on editing what users actually see: posts, pages, Gutenberg blocks, Elementor content, menus, templates, widgets, and settings inside a live preview.

- **Built for the frontend.** Other AI WordPress plugins started as chatbot and content-generation tools, then added site management later. Frontman started as a frontend development tool. It was built to edit what users actually see. That shows in how it handles Elementor edits, template updates, and visual content changes.

- **Cross-framework.** Frontman isn't WordPress-only. The same agent works with Next.js, Astro, and Vite. If your team works across frameworks, you get one tool that works everywhere.

- **Fully open source.** Frontman's source code, including every prompt, every tool definition, and every piece of agent logic, is open on [GitHub](https://github.com/frontman-ai/frontman). Licenses vary by package and integration, and are declared in the source and release artifacts.

The tradeoff: Frontman is newer and more experimental. AI Engine has 100k+ installs, a Pro tier, WooCommerce tools, embeddings, and years of polish. If you need a production-ready AI content pipeline today, AI Engine is solid. If you want an agent that can edit actual WordPress content, Elementor pages, menus, templates, widgets, and settings inside a live preview, that's what Frontman does. For the broader comparison, read [AI Agent Plugins for WordPress Compared](/blog/ai-agent-wordpress-plugin-comparison/).

## Architecture

The integration now runs entirely inside the WordPress plugin.

The plugin handles authentication, serves the `/frontman` route, loads the hosted Frontman UI assets, and exposes WordPress-specific tools for posts, pages, blocks, Elementor content, menus, templates, widgets, and settings. Tool calls are handled server-side in PHP.

## This Is Experimental, and We Need Your Help

This is an early release. The WordPress integration works, but it hasn't been battle-tested across the full range of WordPress setups, including different themes, page builders, hosting environments, and PHP versions.

We're actively looking for WordPress users and developers to try it and help shape where this integration goes next. If you run into issues, have ideas for new tools, or want better support for specific WordPress patterns, we want that feedback directly from real sites and real workflows.

- **Report issues** on [GitHub](https://github.com/frontman-ai/frontman/issues)
- **Join the conversation** and share feedback
- **Contribute**: the codebase is open source on GitHub, with licenses declared per package and integration

## A Note on Production Use

Unlike our JavaScript framework integrations (which are development-only), the WordPress plugin can technically run in production environments. WordPress sites are often edited live, and the plugin respects that workflow.

That said, this is experimental software. If you choose to use it in production, do so with care. We recommend starting in a staging environment, reviewing changes carefully, and keeping backups. The agent makes real content, template, and settings changes, and it may not always do exactly what you intended, so treat it accordingly.

## Getting Started

Frontman is now available in the [WordPress Plugin Directory](https://wordpress.org/plugins/frontman-agentic-ai-editor/). Install it from **Plugins > Add New Plugin** in wp-admin.

We're excited to bring Frontman to the WordPress ecosystem. This is just the beginning, and with your help, it'll get a lot better.
