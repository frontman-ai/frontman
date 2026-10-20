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

This announcement records the addition of WordPress support. The [WordPress setup guide](/docs/integrations/wordpress/) owns current installation and use: WordPress 6.0+, PHP 7.4+, administrator access, Frontman sign-in and service access, and your own supported model connection with separate provider costs.

Open Frontman through the WordPress admin menu after setup. The agent works through supported WordPress operations, not arbitrary theme or plugin source-file edits.

> Describe what you want. The agent handles the supported workflow and shows you the result in the site preview.

No code editor required. No terminal. Just a chat interface alongside a live view of your site.

## What the Agent Can Do

The plugin exposes WordPress-native operations for supported content, Gutenberg blocks, Elementor, navigation, templates, widgets, and selected settings. Settings writes are allowlisted; this is not arbitrary access to configure any installed plugin. The [current capability inventory](/docs/integrations/wordpress/#what-the-agent-can-do) describes each editing surface and its limits.

## How Frontman Compares to Other AI WordPress Plugins

Frontman's focus is supported existing-site editing beside a preview, not every WordPress AI feature. For operator-level tradeoffs, use [AI Agent Plugins for WordPress Compared](/blog/ai-agent-wordpress-plugin-comparison/#the-comparison-that-matters). For chatbots, SEO, forms, content, and other categories, use [Best WordPress AI Plugins](/blog/best-wordpress-ai-plugins-2026/). Those guides own the comparison rather than another changing feature matrix in this announcement.

Frontman's source is available on [GitHub](https://github.com/frontman-ai/frontman). The browser client and JavaScript framework integrations are Apache-2.0, the WordPress plugin is GPL-2.0-or-later, and Frontman Server is AGPL-3.0-only with AI Supplementary Terms.

For one customer result, read how [AutonomyAI's marketing lead redesigned its Elementor site without an agency](/blog/autonomyai-wordpress-redesign-case-study/). The case study separates customer-reported project claims from facts confirmed through public sources and does not present the result as a universal benchmark.

## Architecture

The integration now runs entirely inside the WordPress plugin.

The plugin handles authentication, serves the `/frontman` route, loads the hosted Frontman UI assets, and exposes WordPress-specific tools for posts, pages, blocks, Elementor content, menus, templates, widgets, and settings. Tool calls are handled server-side in PHP.

## Production-Ready WordPress Editing

Frontman for WordPress is production-ready and battle-tested. Themes, page builders, hosting environments, and PHP versions vary, so verify your site's specific workflow.

- **Report issues** on [GitHub](https://github.com/frontman-ai/frontman/issues)
- **Contribute**: the source-available codebase is on GitHub, with an Apache-2.0 browser client and JavaScript integrations, a GPL-2.0-or-later WordPress plugin, and an AGPL-3.0-only server plus AI Supplementary Terms

## A Note on Production Use

The WordPress plugin supports production installations; the JavaScript integrations' supported editing workflow uses a development server. WordPress writes affect the connected site, and published content can change before visual review. Preview is not a universal approval gate.

Keep backups and use staging for higher-risk changes. Only some tools require confirmation, and Elementor snapshots do not provide universal rollback for other surfaces. Read the [recovery boundaries](/docs/integrations/wordpress/#confirmation-and-rollback) before editing.

**Correction, October 20, 2026:** Settings access is allowlisted, and installation also requires Frontman service and provider setup. This announcement now delegates current operations to the setup guide rather than implying unrestricted settings access.

## Getting Started

Frontman is now available in the [WordPress Plugin Directory](https://wordpress.org/plugins/frontman-agentic-ai-editor/). Install it from **Plugins > Add New Plugin** in wp-admin.

Before installing it on your site, [watch one complete staging-safe task](/blog/best-wordpress-ai-plugins-2026/#frontman-workflow-demo) from request through reviewed result.

We're excited to bring Frontman to the WordPress ecosystem. This is just the beginning, and with your help, it'll get a lot better.
