---
title: Frontman Framework Compatibility
description: Check Frontman support and minimum versions for Next.js, Astro, Vite-based apps, and WordPress before choosing an integration.
---

This page owns framework support, versions, and integration choice. Use [Installation](/docs/installation/) for commands and success checks, [Configuration Options](/docs/reference/configuration/) for settings, and [Frontman Agent Tool Capabilities](/docs/using/tool-capabilities/) for individual tool parameters.

Frontman has two compatibility layers:

1. **The browser UI and agent runtime** — the same Frontman interface and hosted orchestration server.
2. **The local integration** — the package or plugin that exposes your project to the agent through framework-specific tools.

Compatibility depends on the local integration. Frontman does not attach directly to arbitrary applications. Supported setup and day-to-day workflows use the framework development server for JavaScript integrations; deployed behavior must still be verified because framework build semantics differ.

If you want the end-to-end execution model behind that split, read [How the Agent Works](/docs/using/how-the-agent-works/) and [Architecture Overview](/docs/reference/architecture/).

## Compatibility summary

| Platform        | Package / integration     | Status    | Minimum versions                       | What Frontman can access                                                                 |
| --------------- | ------------------------- | --------- | -------------------------------------- | ---------------------------------------------------------------------------------------- |
| Next.js         | `@frontman-ai/nextjs`     | Supported | Next.js 15.5-16, Node.js 18+           | Files, route manifest, dev logs, optional OpenTelemetry spans                            |
| Astro           | `@frontman-ai/astro`      | Supported | Astro 5.x, 6.x, or 7.x; Node.js 22.19+ | Files, resolved routes, dev logs, Astro and Frontman source annotations                  |
| Vite-based apps | `@frontman-ai/vite`       | Supported | Vite 5.0+, Node.js 18+                 | Files, dev logs, framework-aware client context                                          |
| WordPress       | Frontman WordPress plugin | Beta      | WordPress 6.0+, PHP 7.4+               | Site content, Elementor, templates, widgets, menus, and settings through WordPress tools |

## How compatibility works

Frontman uses a split architecture:

- The **browser-side client** exposes preview-aware tools such as screenshots, DOM inspection, text search, and element interaction.
- The **framework integration** exposes project-local tools such as file reads, file edits, route discovery, and dev server logs.
- The **Frontman server** orchestrates the agent loop, calls the LLM, and routes tool calls between the browser and the local integration.

That architecture is why support is integration-specific. The hosted server is the same across frameworks, but each local integration decides which tools exist, how routes are discovered, and what source metadata can be recovered.

For the full request/tool flow, see [Architecture Overview](/docs/reference/architecture/).

## Supported integrations

### Next.js

`@frontman-ai/nextjs` integrates through Next.js middleware or proxy entrypoints, depending on your Next.js version.

**Supported versions**

- Next.js 15.5 or later
- Node.js 18 or later

**What the integration provides**

- File access within `projectRoot` / `sourceRoot`
- `get_routes` for App Router and Pages Router discovery
- `get_logs` for console output, build output, and uncaught errors
- Optional OpenTelemetry instrumentation for request and render spans

See [Tool Capabilities](/docs/using/tool-capabilities/) for the shared file, log, and browser tools that work alongside these Next.js-specific capabilities.

**Notes**

- The [generated middleware/proxy](https://github.com/frontman-ai/frontman/blob/main/libs/frontman-nextjs/src/cli/FrontmanNextjs__Cli__Templates.res) contains no automatic development-only guard. Next.js 15.5 uses generated middleware with `runtime: 'nodejs'`; Next.js 16 and later use proxy without a runtime declaration, matching Next.js proxy runtime requirements.
- If that entrypoint remains in the application, its Frontman route matcher can be included in production builds. Add an explicit environment guard or remove it when deployed Frontman access is not intended, and verify the production build and route behavior.
- App Router and Pages Router can coexist in the same project.
- The integration works with both Webpack and Turbopack because it hooks at the Next.js request-entrypoint layer, not the bundler layer.

See [Next.js integration](/docs/integrations/nextjs/).

### Astro

`@frontman-ai/astro` integrates through Astro lifecycle hooks and the underlying Vite dev server.

**Supported versions**

- Astro 5.x, 6.x, or 7.x
- Node.js 22.19 or later

**What the integration provides**

- File access within `projectRoot` / `sourceRoot`
- `get_client_pages` for Astro route discovery
- `get_logs` for Astro and Vite dev output
- Source mapping through Astro 5/6 Dev Toolbar annotations, Frontman-owned Astro 7 annotations, and content-file metadata

**Notes**

- On Astro 5+, route discovery uses the resolved route manifest, which includes content collections, redirects, API endpoints, and integration-injected routes.
- On older behavior paths, filesystem scanning is less complete. Current documentation and support target Astro 5+.
- Astro 5 and 6 require Dev Toolbar annotations for exact element locations. Astro 7 uses Frontman-owned annotations because its Rust compiler does not emit the legacy attributes.
- Both Astro 7's default Sätteri Markdown processor and the optional unified processor are supported.

See [Astro integration](/docs/integrations/astro/).

### Vite-based applications

`@frontman-ai/vite` supports applications that run on a standard Vite dev server.

**Supported versions**

- Vite 5.0 or later
- Node.js 18 or later

**What the integration provides**

- File access within `projectRoot` / `sourceRoot`
- `get_logs` for Vite console, build, and error output
- Framework-aware client context when supported framework plugins are detected
- Vue SFC source mapping through a dev-only source plugin

**Supported framework families on Vite**

- React
- Vue
- Svelte
- SolidJS
- Vanilla JavaScript / TypeScript
- Other Vite-based apps that do not require framework-specific server hooks

**Notes**

- Vite compatibility is based on the dev server and plugin chain. If your project runs on Vite, Frontman can attach through the Vite integration even when the framework itself is not listed separately.
- Framework-specific introspection is strongest for projects whose Vite plugin is explicitly detected.
- SvelteKit works through its Vite dev server path.

See [Vite integration](/docs/integrations/vite/).

### WordPress

The Frontman WordPress plugin is separate from the JavaScript framework integrations.

**Supported versions**

- WordPress 6.0 or later
- PHP 7.4 or later
- Administrator access

**What the integration provides**

- Post, page, block, Elementor, menu, widget, template, and settings tools
- A live preview inside the site itself

**Notes**

- WordPress support is currently beta.
- Supported workflows differ from the code-first integrations because the primary surface is WordPress content and configuration, not a local codebase.

See [WordPress integration](/docs/integrations/wordpress/).

## What is not supported

### Unsupported local runtimes

Frontman does not currently provide first-party integrations for:

- plain Webpack dev servers
- Parcel
- Create React App without Vite migration
- Remix as a standalone integration
- Nuxt as a standalone integration
- Gatsby
- arbitrary static HTML sites without a supported dev server/plugin

A framework may still be usable if it runs through a supported integration path. For example, a framework built on Vite can work through `@frontman-ai/vite` even if Frontman does not document that framework separately. Start with [Installation](/docs/installation/) if you need the package-level setup path.

### Production environments

JavaScript integrations are intended for development workflows. Production builds and preview deployments are not the supported editing workflow, but that does not guarantee integration code is absent.

In practice, that means:

- Astro support applies to `astro dev`, not `astro build` or `astro preview`
- Vite support applies to `vite dev`, not `vite build` or `vite preview`
- Next.js middleware/proxy can execute in a production deployment if the generated or manually integrated entrypoint remains. Frontman does not add an environment guard; deployment owners must add one or remove the integration when needed.

For every integration, run the framework's production build and inspect the deployed result. Confirm whether Frontman routes, middleware/proxy logic, and client assets are emitted and reachable, then apply environment, authentication, reverse-proxy, and network controls appropriate to that result.

### Access outside the integration boundary

Even on supported frameworks, Frontman is limited to what the integration exposes:

- file tools resolve paths against the configured `sourceRoot`, subject to the symlink caveat documented in [Limitations & Workarounds](/docs/using/limitations/)
- browser tools only see the embedded preview, not other tabs or devtools
- there is no shell or terminal access
- private-network `web_fetch` targets are blocked

See [Limitations & Workarounds](/docs/using/limitations/) for the operational constraints that apply across all supported frameworks.

## Choosing the right integration

If you are deciding which package to install:

1. **Use `@frontman-ai/nextjs`** for Next.js applications.
2. **Use `@frontman-ai/astro`** for Astro applications.
3. **Use `@frontman-ai/vite`** for React, Vue, Svelte, SolidJS, SvelteKit, or other apps whose local development server is Vite.
4. **Use the WordPress plugin** for WordPress sites.

If your project is in a monorepo, set `sourceRoot` to the repository root so file tools can reach the files you expect. See [Configuration Options](/docs/reference/configuration/) for the exact settings on each integration.

## Practical compatibility guidance

Before relying on Frontman for day-to-day work, verify these conditions:

1. The app runs on a supported local integration.
2. The dev server is running, and `/frontman` loads successfully.
3. The relevant files are inside the configured `sourceRoot`.
4. The page you want to edit is reachable in the preview without unsupported auth flows or cross-origin boundaries.
5. Your framework-specific features are available through the integration path you chose.

If one of those conditions is false, the issue is usually integration scope rather than agent behavior. When the failure mode is environmental rather than compatibility-related, continue with [Troubleshooting](/docs/reference/troubleshooting/).
