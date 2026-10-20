---
title: 'Frontman WordPress Plugin Is Live'
pubDate: 2026-05-14T05:00:00Z
updatedDate: 2026-10-20T00:00:00Z
description: 'The Frontman WordPress plugin is now live in the WordPress Plugin Directory. Install it from wp-admin and edit your site with an AI agent.'
author: 'Itay Adler'
image: '/blog/frontman-wordpress-plugin-released-cover.png'
imageAlt: 'Frontman WordPress plugin release announcement'
articleSection: 'Product Announcement'
tags: ['announcement', 'wordpress']
---

Installing an AI editor on a WordPress site should feel like installing a WordPress plugin.

Open wp-admin. Search for the plugin. Click install. Activate it. Start editing the site you are already looking at.

That is now the Frontman workflow.

[Frontman for WordPress](/) is live in the WordPress Plugin Directory as **Frontman - AI Website Editor**. It puts an AI agent inside your WordPress site, next to a live preview, with tools for posts, pages, blocks, Elementor pages, menus, templates, widgets, and settings. You can install it from the [Frontman WordPress plugin page](https://wordpress.org/plugins/frontman-agentic-ai-editor/).

If you are comparing the broader category before installing anything, read [Best WordPress AI Plugins in 2026](/blog/best-wordpress-ai-plugins-2026/) for how Frontman, AI Engine, Elementor AI, Divi AI, AIOSEO, WPForms AI, and WordPress AI builders fit different jobs.

### Install Frontman from the WordPress Plugin Directory

Install it from wp-admin like any other WordPress plugin:

1. Open **Plugins -> Add New Plugin** in WordPress.
2. Search for **Frontman - AI Website Editor**.
3. Click **Install Now**.
4. Click **Activate**.
5. Visit `/frontman` on your site while logged in as an administrator.

That installs the plugin. Before editing, sign in to Frontman, confirm service access, and connect your own supported AI provider; provider costs are separate. Follow the [current WordPress installation guide](/docs/integrations/wordpress/#installation) for requirements and configuration. No terminal, separate local server, or framework config is needed.

### What the plugin gives you

Frontman puts an AI agent directly inside your WordPress site. Open `/frontman`, describe the change you want, and the agent works through WordPress-specific tools while you watch the live site preview.

The [current WordPress capability guide](/docs/integrations/wordpress/#what-the-agent-can-do) lists supported content, Elementor, menu, template, and settings operations. That inventory evolves independently of this directory-release announcement.

The important part is not that there is a chat box. WordPress already has plenty of AI chat boxes. The important part is that the agent operates next to a live preview of the page it is changing. You describe the result you want, the plugin runs the appropriate WordPress tools, and you verify the change in the same workflow.

That feedback loop is the difference between "AI generated some content" and "the page now looks right."

### What this looks like in practice

You do not need to translate a visual change into a tour through admin screens.

Say:

- "Rewrite the homepage hero for a local dental clinic."
- "Replace the product card copy and make the CTA clearer."
- "Add a menu item for the pricing page."
- "Update this Elementor section so the headline is shorter and the image matches the new offer."
- "Update the footer menu label before the campaign goes live."

The agent can inspect the site, choose the right WordPress tool, make the edit, and refresh the preview. You still review the result. You still decide what is good enough. The difference is that the work happens in the same place you noticed the problem.

That workflow has also been used beyond one focused edit. [AutonomyAI's Elementor redesign case study](/blog/autonomyai-wordpress-redesign-case-study/) documents a marketer-led site redesign, the evidence that can be checked publicly, and the limits of one customer result.

This matters because WordPress work is rarely just "write some text." It is usually content plus layout plus navigation plus a plugin-specific storage format that someone chose three years ago. Frontman is built around that reality. It uses WordPress APIs and WordPress-specific tools instead of pretending every change is a generic code edit.

### Built for WordPress workflows

The plugin runs inside WordPress and respects WordPress permissions. Only administrators can access Frontman. Tool requests are validated through the plugin. Site option writes are restricted to safe allowlists. The goal is not to bolt a generic coding agent onto a CMS and hope it behaves. The goal is to expose the right WordPress operations to the agent and keep the user in control.

For the execution architecture behind those operations, read the [original WordPress integration announcement](/blog/wordpress-integration/#architecture). For current access, confirmation, and live-site mutation boundaries, use the [WordPress threat model](/blog/security/#wordpress-live-site-threat-model).

### Production-ready, with review in the loop

This is a release announcement, not a claim that every WordPress edge case has been solved.

WordPress is not one platform in practice. It is thousands of themes, page builders, hosting environments, cache layers, security plugins, custom post types, and old decisions nobody remembers making. Usually in production. Usually five minutes before someone needs the page fixed.

Frontman is production-ready and battle-tested. Keep backups. Review changes in the live preview. Use staging for higher-risk changes. The plugin can make real changes to content, menus, templates, Elementor pages, and settings. That power is the point. It is also why the workflow has to be treated seriously.

### Try it

Install [Frontman - AI Website Editor from the WordPress Plugin Directory](https://wordpress.org/plugins/frontman-agentic-ai-editor/), activate it, and open `/frontman` on your site.

The better workflow is simple: describe the change beside the page, inspect the saved result, and use your normal staging or draft publication process. Published content on a live installation can change immediately; the preview is not a universal approval gate.
