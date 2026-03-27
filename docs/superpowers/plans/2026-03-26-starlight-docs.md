# Starlight Docs Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Astro Starlight documentation at `/docs/` to the marketing site with branded styling and navigation links.

**Architecture:** Starlight runs as an Astro integration with its own layout, isolated from marketing pages. `@astrojs/starlight-tailwind` v5 bridges Starlight's theme system with the existing TW4 setup via CSS cascade layers. Content lives in `src/content/docs/` and is registered as a collection alongside blog/glossary/lighthouse.

**Tech Stack:** Astro 6, Starlight, @astrojs/starlight-tailwind v5, Tailwind CSS v4

**Pre-work completed:** `npx astro add starlight --yes` was run, which:
- Installed `@astrojs/starlight` and added it to `package.json`
- Added `import starlight from "@astrojs/starlight"` to `astro.config.mjs`
- Appended `starlight()` (unconfigured) to end of integrations array

**Remaining:** Configure starlight with branding/sidebar, move it to first integration, add starlight-tailwind, create CSS, content, and nav links.

---

### Task 1: Add starlight-tailwind Dependency and Commit Generator Output

**Files:**
- Modify: `apps/marketing/package.json` (already modified by generator)
- Modify: `yarn.lock` (already modified by generator)

- [ ] **Step 1: Add starlight-tailwind**

```bash
cd apps/marketing && yarn add @astrojs/starlight-tailwind
```

- [ ] **Step 2: Verify both packages installed**

```bash
cd apps/marketing && yarn info @astrojs/starlight --json 2>/dev/null | head -1
yarn info @astrojs/starlight-tailwind --json 2>/dev/null | head -1
```

Expected: Both packages resolve with versions.

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/package.json yarn.lock apps/marketing/astro.config.mjs
git commit -m "feat(marketing): add @astrojs/starlight and starlight-tailwind via astro add generator"
```

---

### Task 2: Create Starlight Custom CSS

**Files:**
- Create: `apps/marketing/src/styles/starlight.css`

- [ ] **Step 1: Create the Starlight CSS file**

Create `apps/marketing/src/styles/starlight.css` with the following content:

```css
@layer base, starlight, theme, components, utilities;
@import '@astrojs/starlight-tailwind';
@import 'tailwindcss/theme.css' layer(theme);
@import 'tailwindcss/utilities.css' layer(utilities);

@theme {
  /* Fonts — match marketing site (from global.css) */
  --font-sans: 'Inter Variable', ui-sans-serif, system-ui, sans-serif,
    'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';
  --font-heading: 'Outfit Variable', ui-sans-serif, system-ui, sans-serif,
    'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol', 'Noto Color Emoji';

  /* Starlight accent = Frontman primary purple (from global.css --color-primary-*) */
  --color-accent-50: #faf5ff;
  --color-accent-100: #f3e8ff;
  --color-accent-200: #e9d5ff;
  --color-accent-300: #d8b4ff;
  --color-accent-400: #c084ff;
  --color-accent-500: #a259ff;
  --color-accent-600: #8847d9;
  --color-accent-700: #6e38b3;
  --color-accent-800: #552c8c;
  --color-accent-900: #3c1f66;
  --color-accent-950: #23123d;

  /* Starlight gray = Frontman neutral/slate (from global.css --color-neutral-*) */
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

- [ ] **Step 2: Commit**

```bash
git add apps/marketing/src/styles/starlight.css
git commit -m "feat(marketing): add Starlight custom CSS with Frontman brand colors"
```

---

### Task 3: Configure Starlight Integration

**Files:**
- Modify: `apps/marketing/astro.config.mjs`

The generator already added the import and an unconfigured `starlight()` at the end of the integrations array. We need to:
1. Move `starlight()` to the **first** position in the integrations array
2. Add the full configuration (title, logo, social, sidebar, customCss, editLink)
3. Add a docs sitemap chunk

- [ ] **Step 1: Replace the unconfigured starlight() with full config at first position**

In `apps/marketing/astro.config.mjs`, the current integrations array looks like:

```js
  integrations: [frontman({...}), icon(), brokenLinksChecker(), sitemap({...}), starlight()],
```

Change it to put the configured `starlight()` first and remove the trailing unconfigured one:

```js
  integrations: [
    starlight({
      title: "Frontman",
      logo: {
        src: "/logo.svg",
      },
      social: [
        {
          icon: "github",
          label: "GitHub",
          link: "https://github.com/frontman-ai/frontman",
        },
        {
          icon: "discord",
          label: "Discord",
          link: "https://discord.gg/xk8uXJSvhC",
        },
        {
          icon: "x.com",
          label: "X",
          link: "https://twitter.com/frontman_agent",
        },
      ],
      sidebar: [
        {
          label: "Getting Started",
          items: [
            { label: "Introduction", slug: "docs" },
            { label: "Installation", slug: "docs/installation" },
            { label: "Quick Start", slug: "docs/quick-start" },
          ],
        },
        { label: "Guides", autogenerate: { directory: "docs/guides" } },
        { label: "Reference", autogenerate: { directory: "docs/reference" } },
      ],
      customCss: ["./src/styles/starlight.css"],
      editLink: {
        baseUrl:
          "https://github.com/frontman-ai/frontman/edit/main/apps/marketing/",
      },
    }),
    frontman({
      projectRoot: appRoot,
      sourceRoot: monorepoRoot,
      basePath: "frontman",
      serverName: "marketing",
    }),
    icon(),
    brokenLinksChecker(),
    sitemap({
      // ... existing sitemap config unchanged except for the new docs chunk
    }),
  ],
```

- [ ] **Step 2: Add docs sitemap chunk**

In the `chunks` object inside the `sitemap()` config, add a docs chunk:

```js
        docs: (item) => {
          if (/\/docs\//.test(item.url)) return item;
        },
```

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/astro.config.mjs
git commit -m "feat(marketing): configure Starlight integration with sidebar and branding"
```

---

### Task 4: Register Docs Content Collection

**Files:**
- Modify: `apps/marketing/src/content.config.ts`

- [ ] **Step 1: Add docs collection**

Add the Starlight imports at the top of `apps/marketing/src/content.config.ts`:

```ts
import { docsLoader, docsSchema } from '@astrojs/starlight/loaders'
```

Add the docs collection definition after the `lighthouse` collection:

```ts
const docs = defineCollection({
	loader: docsLoader(),
	schema: docsSchema(),
})
```

Add `docs` to the exports:

```ts
export const collections = {
	blog,
	glossary,
	lighthouse,
	docs,
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/marketing/src/content.config.ts
git commit -m "feat(marketing): register docs content collection with Starlight loader"
```

---

### Task 5: Create Stub Content Pages

**Files:**
- Create: `apps/marketing/src/content/docs/index.md`
- Create: `apps/marketing/src/content/docs/installation.md`
- Create: `apps/marketing/src/content/docs/quick-start.md`
- Create: `apps/marketing/src/content/docs/guides/index.md`
- Create: `apps/marketing/src/content/docs/reference/index.md`

- [ ] **Step 1: Create content directories**

```bash
mkdir -p apps/marketing/src/content/docs/guides
mkdir -p apps/marketing/src/content/docs/reference
```

- [ ] **Step 2: Create index.md**

Create `apps/marketing/src/content/docs/index.md`:

```md
---
title: Frontman Documentation
description: Learn how to install, configure, and use Frontman to bridge the gap between design and development.
---

Welcome to the Frontman documentation. Frontman lets you skip the "refresh and check" cycle and brings non-coding teammates into the workflow.

## Getting Started

- [Installation](/docs/installation/) — Install Frontman in your project
- [Quick Start](/docs/quick-start/) — Get up and running in minutes

## Guides

Step-by-step guides for common tasks and workflows.

## Reference

API reference and configuration options.
```

- [ ] **Step 3: Create installation.md**

Create `apps/marketing/src/content/docs/installation.md`:

```md
---
title: Installation
description: How to install Frontman in your project.
---

Install Frontman in your project using your preferred package manager.

## npm

```bash
npm install frontman
```

## yarn

```bash
yarn add frontman
```

## pnpm

```bash
pnpm add frontman
```
```

- [ ] **Step 4: Create quick-start.md**

Create `apps/marketing/src/content/docs/quick-start.md`:

```md
---
title: Quick Start
description: Get up and running with Frontman in minutes.
---

This guide walks you through setting up Frontman in an existing project.

## Prerequisites

- Node.js 18 or later
- A supported framework (Next.js, Astro, or Vite)

## Setup

1. Install Frontman in your project
2. Add the Frontman integration to your framework config
3. Start your development server

Detailed instructions for each framework are available in the [Integrations](/integrations/) section.
```

- [ ] **Step 5: Create guides/index.md**

Create `apps/marketing/src/content/docs/guides/index.md`:

```md
---
title: Guides
description: Step-by-step guides for common Frontman tasks and workflows.
---

Guides for working with Frontman will be added here as the documentation grows.
```

- [ ] **Step 6: Create reference/index.md**

Create `apps/marketing/src/content/docs/reference/index.md`:

```md
---
title: Reference
description: API reference and configuration options for Frontman.
---

API reference and configuration documentation will be added here as the documentation grows.
```

- [ ] **Step 7: Commit**

```bash
git add apps/marketing/src/content/docs/
git commit -m "feat(marketing): add stub documentation content pages"
```

---

### Task 6: Add Navigation Links

**Files:**
- Modify: `apps/marketing/src/config/navigationBar.ts`
- Modify: `apps/marketing/src/config/footerNavigation.ts`

- [ ] **Step 1: Add Docs to navbar**

In `apps/marketing/src/config/navigationBar.ts`, add a "Docs" entry as the **first** item in the `navItems` array:

```ts
	navItems: [
		{ name: 'Docs', link: '/docs/' },
		{
			name: 'Compare',
			// ... rest unchanged
```

- [ ] **Step 2: Add Documentation to footer**

In `apps/marketing/src/config/footerNavigation.ts`, add a "Documentation" entry to the **Developers** column (the 5th column), as the first subCategory:

```ts
		{
			category: 'Developers',
			subCategories: [
				{
					subCategory: 'Documentation',
					subCategoryLink: '/docs/'
				},
				{
					subCategory: 'GitHub',
					// ... rest unchanged
```

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/src/config/navigationBar.ts apps/marketing/src/config/footerNavigation.ts
git commit -m "feat(marketing): add Docs link to navbar and footer navigation"
```

---

### Task 7: Build and Verify

**Files:** None (verification only)

**Pre-requisite:** `@frontman-ai/astro` must be built. It was already built during pre-work (`cd libs/frontman-astro && yarn build`). If you get import errors, rebuild it.

- [ ] **Step 1: Run production build**

```bash
cd apps/marketing && yarn build
```

Expected: Build succeeds. Look for docs pages in the output:
- `dist/docs/index.html`
- `dist/docs/installation/index.html`
- `dist/docs/quick-start/index.html`
- `dist/docs/guides/index.html`
- `dist/docs/reference/index.html`

- [ ] **Step 2: Verify docs appear in sitemap**

```bash
grep -r "docs" apps/marketing/dist/sitemap*.xml | head -10
```

Expected: Docs URLs appear in a `sitemap-docs-0.xml` chunk.

- [ ] **Step 3: Verify marketing pages are unaffected**

```bash
ls apps/marketing/dist/index.html
ls apps/marketing/dist/blog/index.html
ls apps/marketing/dist/faq/index.html
```

Expected: All three files exist (marketing pages still build).

- [ ] **Step 4: Start dev server and manually verify**

```bash
cd apps/marketing && yarn dev
```

Check in browser:
- `/` — marketing homepage renders normally
- `/blog/` — blog page renders normally
- `/docs/` — Starlight docs page renders with purple accent, Inter/Outfit fonts
- `/docs/installation/` — installation page renders
- `/docs/quick-start/` — quick start page renders
- Sidebar navigation works (Getting Started, Guides, Reference sections)
- Pagefind search icon is present in docs header

- [ ] **Step 5: Commit any fixes if needed**

Only commit if there were fixes needed during verification. If everything passed cleanly, skip this step.

```bash
git add -A
git commit -m "fix(marketing): address issues found during Starlight docs verification"
```
