# Starlight Docs Integration — Design Spec

**Issue:** #709 — feat: add Starlight docs to marketing site at /docs/
**Date:** 2026-03-26

## Overview

Add Astro Starlight documentation framework to the marketing site (`apps/marketing/`), serving product docs at `/docs/`. Starlight runs as an Astro integration with its own layout — marketing pages are unaffected.

## Architecture

Starlight is added as the **first** integration in `astro.config.mjs`. It owns the `/docs/` route prefix and renders using its own layout. Marketing pages (`/`, `/blog/`, `/faq/`, etc.) continue to use the existing `Layout.astro`.

```
astro.config.mjs
  └─ integrations: [starlight({...}), sitemap(), ...]
  └─ vite: { plugins: [tailwindcss()] }  ← already in place

src/content/docs/       ← Starlight content directory
src/styles/starlight.css ← Starlight-specific styles (separate from global.css)
```

The existing `trailingSlash: 'always'` config is global and Starlight honors it. Verify during implementation that sidebar slug references resolve correctly with trailing slashes.

## Dependencies

- `@astrojs/starlight` — Starlight framework
- `@astrojs/starlight-tailwind` v5 — TW4-compatible integration (dark mode, theme mapping, Preflight restore)

## Config Changes

### astro.config.mjs

Add `starlight()` as the first integration:

```js
import starlight from '@astrojs/starlight';

starlight({
  title: 'Frontman',
  logo: {
    src: '/logo.svg',  // from public/logo.svg
  },
  social: [
    { icon: 'github', label: 'GitHub', link: 'https://github.com/frontman-ai/frontman' },
    { icon: 'discord', label: 'Discord', link: 'https://discord.gg/xk8uXJSvhC' },
    { icon: 'x.com', label: 'X', link: 'https://twitter.com/frontman_agent' },
  ],
  sidebar: [
    {
      label: 'Getting Started',
      items: [
        { label: 'Introduction', slug: 'docs' },
        { label: 'Installation', slug: 'docs/installation' },
        { label: 'Quick Start', slug: 'docs/quick-start' },
      ],
    },
    { label: 'Guides', autogenerate: { directory: 'docs/guides' } },
    { label: 'Reference', autogenerate: { directory: 'docs/reference' } },
  ],
  customCss: ['./src/styles/starlight.css'],
  editLink: {
    baseUrl: 'https://github.com/frontman-ai/frontman/edit/main/apps/marketing/',
  },
})
```

Sitemap: add a docs chunk to the existing sitemap config.

### src/content.config.ts

Add docs collection using Starlight's loader and schema:

```ts
import { docsLoader, docsSchema } from '@astrojs/starlight/loaders';

const docs = defineCollection({
  loader: docsLoader(),
  schema: docsSchema(),
});

export const collections = { blog, glossary, lighthouse, docs };
```

### Navigation

- `src/config/navigationBar.ts` — add `{ text: 'Docs', href: '/docs/' }` as the first nav item
- `src/config/footerNavigation.ts` — add `{ text: 'Documentation', href: '/docs/' }` under Developers column

## Styling

New file: `src/styles/starlight.css` — loaded only on docs pages via `customCss`.

Uses the CSS layer approach for TW4 compatibility:

```css
@layer base, starlight, theme, components, utilities;
@import '@astrojs/starlight-tailwind';
@import 'tailwindcss/theme.css' layer(theme);
@import 'tailwindcss/utilities.css' layer(utilities);

@theme {
  --font-sans: 'Inter Variable', ui-sans-serif, system-ui, sans-serif;
  --font-heading: 'Outfit Variable', ui-sans-serif, system-ui, sans-serif;

  /* Accent = Frontman primary purple */
  --color-accent-50: #FAF5FF;
  --color-accent-100: #F3E8FF;
  --color-accent-200: #E9D5FF;
  --color-accent-300: #D8B4FF;
  --color-accent-400: #C084FF;
  --color-accent-500: #A259FF;
  --color-accent-600: #8847D9;
  --color-accent-700: #6E38B3;
  --color-accent-800: #552C8C;
  --color-accent-900: #3C1F66;
  --color-accent-950: #23123D;

  /* Gray = Frontman neutral (slate) */
  --color-gray-50: #f8fafc;
  --color-gray-100: #f1f5f9;
  --color-gray-200: #e2e8f0;
  --color-gray-300: #cbd5e1;
  --color-gray-400: #94a3b8;
  --color-gray-500: #64748b;
  --color-gray-600: #475569;
  --color-gray-700: #334155;
  --color-gray-800: #1e293b;
  --color-gray-900: #0f172a;
}
```

The existing `global.css` is **not modified**. Cascade layers prevent style conflicts between Starlight and marketing pages.

## Content Structure

Stub markdown files with minimal frontmatter (`title`, `description`) and placeholder content:

```
src/content/docs/
  index.md              → /docs/
  installation.md       → /docs/installation/
  quick-start.md        → /docs/quick-start/
  guides/
    index.md            → /docs/guides/
  reference/
    index.md            → /docs/reference/
```

`guides/` and `reference/` use `autogenerate` in sidebar config — any `.md` file added to those directories automatically appears in the sidebar.

## What Is NOT Changing

- Existing marketing pages, layouts, components
- `global.css` — untouched
- Existing content collections (blog, glossary, lighthouse)
- Build pipeline — `yarn build` continues to work

## Acceptance Criteria

1. Marketing pages render normally at `/`, `/blog/`, `/faq/`, etc.
2. Docs render at `/docs/`, `/docs/installation/`, `/docs/quick-start/`
3. Starlight sidebar navigation works
4. Brand colors (purple accent) and fonts (Inter/Outfit) match marketing site
5. "Docs" link appears in navbar and footer
6. `yarn build` succeeds with docs in sitemap
7. Pagefind search works within docs
