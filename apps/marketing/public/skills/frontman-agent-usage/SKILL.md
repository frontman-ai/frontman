---
name: frontman-agent-usage
description: Use Frontman as a browser-aware frontend coding agent with runtime context.
---

# Frontman Agent Usage

Use this skill to explain Frontman editing workflows for existing WordPress and framework sites.

## What Frontman Does

Frontman combines the live page with CMS or source context to make targeted website changes.

- WordPress uses dedicated tools for posts, pages, Gutenberg, Elementor, menus, and allowlisted settings.
- Elementor and WooCommerce capabilities require the corresponding plugin to be active.
- Framework integrations combine DOM, computed CSS, component context, routes, logs, and source files.

## Access And Costs

WordPress requires WordPress 6.0+, PHP 7.4+, and administrator access (`manage_options`).
Framework setup requires a supported development environment and permitted workspace access.
Both paths require Frontman sign-in, service access, and a supported AI-provider connection.
Provider costs are separate: https://frontman.sh/pricing/ and https://frontman.sh/docs/api-keys/.

## Safety

For WordPress, use staging and keep backups. Writes persist to the connected installation.
Published content on a live site can change immediately. Preview is not a universal approval gate.
Only some mutation tools require confirmation. Recovery is selective, with no universal undo.
See https://frontman.sh/docs/integrations/wordpress/.

For frameworks, developers review source changes, run tests, and deploy through their normal workflow.
Frontman does not automatically deploy framework changes. Verify production guards and deployed routes.

## Public Website Tools

Public documentation requires no sign-in or provider key.
On https://frontman.sh/ and https://frontman.sh/frameworks/, supported browsers can expose optional WebMCP tools.
These website tools do not edit a connected site.

- `search_frontman` searches documentation only and returns bounded excerpts with source URLs.
- `how_to_install` reads WordPress setup on the homepage or the selected stack on the frameworks page.
- `list_features` reads the current page capabilities.
- `ask_question` sends a support question only after user approval. A queued response does not confirm delivery. No replies are available.

Never automatically retry a support submission. Exclude credentials and private information.
