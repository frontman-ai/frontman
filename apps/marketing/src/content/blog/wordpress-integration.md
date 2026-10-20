---
title: 'AI Editing for WordPress'
seoTitle: 'AI WordPress Editor Plugin'
pubDate: 2026-03-31T05:00:00Z
description: 'Use Frontman as an AI WordPress editor plugin for content, Elementor pages, menus, templates, widgets, settings, and live site preview.'
author: 'Itay Adler'
articleSection: 'Product Announcement'
image: '/blog/frontman-now-supports-wordpress-cover.png'
imageAlt: 'Frontman AI editing for WordPress announcement cover'
tags: ['announcement', 'wordpress']
updatedDate: 2026-10-20T00:00:00Z
---

We started Frontman with a clear idea: put an AI agent inside the app, not the editor. That worked great for JavaScript frameworks like Next.js, Astro, and Vite. But one question kept coming up: what about WordPress?

WordPress powers over 40% of the web. Millions of sites, run by people who range from full-time developers to business owners who just want their site to look right. So we built a WordPress integration.

**Quick answer:** [Frontman for WordPress](/) is an AI WordPress editor plugin that lets you describe changes in plain English, edit WordPress content and Elementor pages, and verify the result in a live site preview.

## How It Works

Install the Frontman plugin, navigate to `/frontman` on your WordPress site, and start talking. The AI agent can work with your content, Elementor pages, menus, templates, widgets, and settings. It can make changes on your behalf.

> Describe what you want. The agent handles the supported workflow and shows you the result in the site preview.

No code editor required. No terminal. Just a chat interface alongside a live view of your site.

## What the Agent Can Do

The integration adds dedicated WordPress operations rather than treating every page as a source file. Examples include changing post or page content, inspecting Elementor widgets, managing menus, and updating allowlisted core settings.

The [current capability guide](/docs/integrations/wordpress/#what-the-agent-can-do) owns the complete inventory and limits. Supported core settings do not imply arbitrary plugin configuration.

## How Frontman Compares to Other AI WordPress Plugins

This announcement introduces the WordPress execution path. Choosing between live site editing, AI content features, and external-client tool access is a separate decision: use [AI Agent Plugins for WordPress Compared](/blog/ai-agent-wordpress-plugin-comparison/). For the broader category map, use [Best WordPress AI Plugins](/blog/best-wordpress-ai-plugins-2026/).

For one customer result, read how [AutonomyAI's marketing lead redesigned its Elementor site without an agency](/blog/autonomyai-wordpress-redesign-case-study/). The case study separates customer-reported project claims from facts confirmed through public sources and does not present the result as a universal benchmark.

## Architecture

The integration now runs entirely inside the WordPress plugin.

The plugin handles authentication, serves the `/frontman` route, loads the hosted Frontman UI assets, and exposes WordPress-specific tools for posts, pages, blocks, Elementor content, menus, templates, widgets, and settings. Tool calls are handled server-side in PHP.

## Production-Ready WordPress Editing

Frontman for WordPress is production-ready and battle-tested. Themes, page builders, hosting environments, and PHP versions vary, so verify your site's specific workflow.

- **Report issues** on [GitHub](https://github.com/frontman-ai/frontman/issues)
- **Contribute**: the source-available codebase is on GitHub, with an Apache-2.0 browser client and JavaScript integrations, a GPL-2.0-or-later WordPress plugin, and an AGPL-3.0-only server plus AI Supplementary Terms

## A Note on Production Use

Unlike our JavaScript framework integrations (which are development-only), the WordPress plugin supports production environments. WordPress sites are often edited live, and the plugin respects that workflow.

Keep backups and review changes in the live preview. Use staging for higher-risk changes. The agent makes real content, template, and settings changes, so verify the result before you consider the task complete.

## Getting Started

For directory availability and its launch context, see the [WordPress plugin release announcement](/blog/frontman-wordpress-plugin-released/). For today's installation, account, and provider requirements, use the [WordPress setup guide](/docs/integrations/wordpress/#installation).

Before installing it on your site, [watch one complete staging-safe task](/blog/best-wordpress-ai-plugins-2026/#frontman-workflow-demo) from request through reviewed result.

We're excited to bring Frontman to the WordPress ecosystem. This is just the beginning, and with your help, it'll get a lot better.
