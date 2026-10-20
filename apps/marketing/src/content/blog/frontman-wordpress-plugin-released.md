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

This announcement marks Frontman's availability in the WordPress Plugin Directory. For current installation, requirements, and recovery details, use the [WordPress setup guide](/docs/integrations/wordpress/).

Installing an AI editor on a WordPress site should feel like installing a WordPress plugin.

Open wp-admin. Search for the plugin. Click install. Activate it. Start editing the site you are already looking at.

That is now the Frontman workflow.

[Frontman for WordPress](/) is live in the WordPress Plugin Directory as **Frontman - Agentic AI Editor**. It puts an AI agent inside your WordPress site, next to a live preview, with tools for posts, pages, blocks, Elementor pages, menus, templates, widgets, and settings. You can install it from the [Frontman WordPress plugin page](https://wordpress.org/plugins/frontman-agentic-ai-editor/).

If you are comparing the broader category before installing anything, read [Best WordPress AI Plugins in 2026](/blog/best-wordpress-ai-plugins-2026/) for how Frontman, AI Engine, Elementor AI, Divi AI, AIOSEO, WPForms AI, and WordPress AI builders fit different jobs.

### Install Frontman from the WordPress Plugin Directory

Install it from wp-admin like any other WordPress plugin:

1. Open **Plugins -> Add New Plugin** in WordPress.
2. Search for **Frontman Agentic AI Editor**.
3. Click **Install Now**.
4. Click **Activate**.
5. Open **Frontman** from the WordPress admin menu while logged in as an administrator.
6. Complete separate Frontman sign-in, confirm service access, and connect your own supported AI provider. Provider costs are separate.

The plugin requires WordPress 6.0+ and PHP 7.4+. It loads Frontman's hosted interface and connects to the Frontman service; plugin activation alone is not complete agent setup. No terminal or framework configuration is needed for this plugin installation.

### What the plugin gives you

Frontman puts an AI agent directly inside your WordPress site. Open `/frontman`, describe the change you want, and the agent works through WordPress-specific tools while you watch the live site preview.

Its [current WordPress tool inventory](/docs/integrations/wordpress/#what-the-agent-can-do) covers supported content, Gutenberg, Elementor, navigation, templates, widgets, and selected settings. Use that maintained reference for exact capabilities rather than treating this release announcement as a complete list.

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

That architecture is why Frontman can handle more than draft generation. It can work with Gutenberg blocks, Elementor content, menus, templates, widgets, and settings. It can move between the visible page and the underlying WordPress structures that produce it.

That is the useful version of AI for WordPress: not a blank prompt box, not a content generator isolated from the page, but an agent that can see the site, use WordPress tools, and show you what changed.

### Production-ready, with review in the loop

This is a release announcement, not a claim that every WordPress edge case has been solved.

WordPress is not one platform in practice. It is thousands of themes, page builders, hosting environments, cache layers, security plugins, custom post types, and old decisions nobody remembers making. Usually in production. Usually five minutes before someone needs the page fixed.

Frontman supports production installations, but published content can change immediately, before visual review. Preview is not an approval gate, and not every mutation requires confirmation. Keep backups and use staging for higher-risk work. Elementor rollback snapshots do not constitute a universal undo system; read the [confirmation and recovery limits](/docs/integrations/wordpress/#confirmation-and-rollback).

### Try it

Install [Frontman - Agentic AI Editor from the WordPress Plugin Directory](https://wordpress.org/plugins/frontman-agentic-ai-editor/), activate it, and open `/frontman` on your site.

Start with a staging site, describe one supported change, and inspect the result before using your normal publication process.

**Correction, October 20, 2026:** Plugin activation is not the whole setup: hosted sign-in, service access, and a supported provider connection are also required. Preview does not defer writes to the connected installation.
