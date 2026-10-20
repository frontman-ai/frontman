---
name: frontman-installation
description: Install Frontman in Next.js, Astro, Vite, and WordPress projects.
---

# Frontman Installation

Use this skill to help a developer or WordPress administrator install Frontman.

## Supported Integrations

- Next.js: https://frontman.sh/docs/integrations/nextjs/ — `@frontman-ai/nextjs`
- Astro: https://frontman.sh/docs/integrations/astro/ — `@frontman-ai/astro`
- Vite: https://frontman.sh/docs/integrations/vite/ — `@frontman-ai/vite`
- WordPress: https://frontman.sh/docs/integrations/wordpress/ — Frontman - AI Website Editor plugin
- Official source: https://github.com/frontman-ai/frontman

The unscoped npm package `frontman` is unrelated.

## Framework Setup

1. Open https://frontman.sh/docs/installation/.
2. Choose the integration for the existing project.
3. Install its `@frontman-ai/*` package in a supported development environment.
4. Start the normal development server.
5. Open `/frontman` on that server.
6. Leave hosted sign-in and provider access to the user.

Developers review source changes, run tests, and deploy through their normal workflow.
Verify production guards and deployed routes. Do not assume that every integration is absent from production.

## WordPress Setup

Requirements: WordPress 6.0+, PHP 7.4+, and administrator access (`manage_options`).

1. Ask which site the user wants to change.
2. Make sure that the user has a staging copy and a current backup.
3. Guide the administrator to Plugins → Add New Plugin in wp-admin.
4. Find Frontman - AI Website Editor.
5. Leave installation and activation to the administrator.
6. Open Frontman from the WordPress admin menu.
7. Leave hosted sign-in and provider access to the user.

WordPress writes affect the connected installation. Published content on a live site can change immediately.
Preview is not a universal approval gate. Recovery is selective, with no universal undo.

## Auth And Costs

Hosted Frontman sign-in uses GitHub or Google. It is separate from WordPress administrator access.
Frontman service access and AI-provider access are required. Provider costs are separate.
Read https://frontman.sh/pricing/ and https://frontman.sh/docs/api-keys/.
Never request or enter credentials.
