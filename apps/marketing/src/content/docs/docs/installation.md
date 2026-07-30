---
title: Install Frontman
description: Choose the right Frontman integration, install it, open the agent, verify setup, and remove it when needed.
---

Frontman attaches to a supported development server through a framework integration, or to WordPress through its plugin. Choose one path below; do not install multiple Frontman integrations for the same app.

This page owns the end-to-end installation outcome. Integration guides own manual configuration and framework-specific troubleshooting, while [Frontman Framework Compatibility](/docs/reference/compatibility/) owns supported versions.

## Prerequisites

- A project using Next.js, Astro, Vite, or WordPress
- A local development server for JavaScript integrations, or WordPress administrator access for the plugin
- A GitHub or Google account for hosted Frontman sign-in
- A supported AI provider connection or API key

Check exact framework, Node.js, WordPress, and PHP requirements in [Frontman Framework Compatibility](/docs/reference/compatibility/) before installing.

## Choose an integration

| Your project                                                           | Install                   |
| ---------------------------------------------------------------------- | ------------------------- |
| Next.js App Router or Pages Router                                     | `@frontman-ai/nextjs`     |
| Astro                                                                  | `@frontman-ai/astro`      |
| React, Vue, Svelte, SolidJS, SvelteKit, or another app running on Vite | `@frontman-ai/vite`       |
| WordPress                                                              | Frontman WordPress plugin |

## Astro

```bash
npx astro add @frontman-ai/astro
```

The Astro installer adds the integration to your Astro config. Continue with the [Astro integration guide](/docs/integrations/astro/) for manual setup, monorepos, or a custom Frontman host.

## Next.js

```bash
npx @frontman-ai/nextjs install
```

The installer detects your Next.js version and writes the appropriate middleware or proxy entrypoint. Continue with the [Next.js integration guide](/docs/integrations/nextjs/) if your project already has middleware, uses a `src/` layout, or needs manual setup.

## Vite

```bash
npx @frontman-ai/vite install
```

The installer adds `frontmanPlugin()` to your Vite config. Continue with the [Vite integration guide](/docs/integrations/vite/) for plugin ordering, manual setup, or framework-specific notes.

## WordPress (Beta)

Install **Frontman - Agentic AI Editor** from the [WordPress Plugin Directory](https://wordpress.org/plugins/frontman-agentic-ai-editor/) in wp-admin. No npm package required.

Activate the plugin, then open `/frontman` on your site. See [Install and Use Frontman for WordPress](/docs/integrations/wordpress/) for requirements, sign-in, supported workflows, and WordPress-specific troubleshooting.

## Verify installation

For Next.js, Astro, or Vite:

1. Start the normal development server for your app.
2. Open `/frontman` on the same local origin, such as `http://localhost:3000/frontman`.
3. Sign in with GitHub or Google if redirected to Frontman's hosted server.
4. Confirm the Frontman chat and live preview load.
5. Open **Settings → Providers** and [connect a provider](/docs/api-keys/).
6. Confirm the model selector offers a model from the connected provider.

Use the framework's development server for this functional installation check. Then run the normal production build and deployment verification for your app: confirm whether Frontman routes and client assets are present, whether `/frontman` is reachable, and whether your intended environment or network controls block access.

Next.js differs from Astro and Vite here. Its [installer templates](https://github.com/frontman-ai/frontman/blob/main/libs/frontman-nextjs/src/cli/FrontmanNextjs__Cli__Templates.res) write request middleware for Next.js 15 and earlier or a proxy for Next.js 16 and later. Generated code has no automatic development-only guard, so it can compile into and run with a production deployment while its matcher includes Frontman routes. Add your own environment guard or remove the integration before deployment when Frontman must be absent, then verify the built artifact rather than assuming `next build` removes it.

For WordPress, verify that an administrator can open `/frontman`, complete hosted sign-in, and see the site preview beside chat.

## Update Frontman

JavaScript integrations are project dependencies. Update the relevant `@frontman-ai/*` package with the package manager used by your project, then restart the development server. Review the [changelog](/changelog/) before adopting changes that affect integration setup.

WordPress uses the normal plugin update flow in wp-admin.

## Remove Frontman

For a JavaScript project:

1. Remove the Frontman integration call from `astro.config.*` or `vite.config.*`, or remove the Frontman middleware/proxy code from the Next.js entrypoint.
2. Remove the matching `@frontman-ai/astro`, `@frontman-ai/nextjs`, or `@frontman-ai/vite` dependency with your package manager.
3. Restart the development server and confirm `/frontman` is no longer mounted by the integration.

If the Next.js installer added a dedicated middleware or proxy file, delete that file only when it contains no non-Frontman logic. If Frontman was merged into an existing file, remove only the Frontman import, handler, and matcher entries.

For WordPress, deactivate and delete the plugin through **Plugins** in wp-admin. Deactivation removes the Frontman route from normal use; it does not revoke provider credentials stored on your Frontman account. Manage those separately through [API Keys & Providers](/docs/api-keys/).

## Setup problems

- **`/frontman` returns 404 during setup:** confirm the integration is registered and restart the development server. For production or preview behavior, inspect and test the built artifact instead of using a 404 as the installation criterion.
- **Sign-in completes on the hosted page but does not return:** reopen `/frontman` on your local app. Custom local hostnames may not be accepted as return URLs.
- **Chat loads but a run cannot start:** configure a credential for the selected model in [API Keys & Providers](/docs/api-keys/).
- **File tools cannot reach expected files:** check `projectRoot` and `sourceRoot` in [Configuration Options](/docs/reference/configuration/).

Use [Troubleshooting](/docs/reference/troubleshooting/) for connection, tool, or preview failures after installation.

## Next steps

1. **[Configure Frontman API Keys & Providers](/docs/api-keys/)** — connect model access
2. **[Sending Prompts](/docs/using/sending-prompts/)** — run a focused first task
3. **[Annotations](/docs/using/annotations/)** — point Frontman at an exact UI element
