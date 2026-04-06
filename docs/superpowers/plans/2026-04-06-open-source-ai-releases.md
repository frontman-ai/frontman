# Open Source AI Releases Pages — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a monthly releases resource at `/open-source-ai-releases/` targeting the "open source ai projects released [month] [year]" search intent, plus update the existing comparison post with a cross-link.

**Architecture:** New `releases` content collection with markdown files per month. An index page lists all editions. A dynamic `[slug].astro` page renders each month. Structured data (ItemList, FAQPage, CollectionPage) on all pages. The existing comparison post gets an `updatedDate` bump and a callout linking to the new resource.

**Tech Stack:** Astro content collections, Zod schemas, JSON-LD structured data, Tailwind CSS.

**Spec:** `docs/superpowers/specs/2026-04-06-open-source-ai-releases-page-design.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `apps/marketing/src/content/releases/march-2026.md` | Seed content — March 2026 roundup |
| Create | `apps/marketing/src/content/releases/april-2026.md` | Seed content — April 2026 roundup |
| Modify | `apps/marketing/src/content.config.ts` | Add `releases` collection with Zod schema |
| Create | `apps/marketing/src/pages/open-source-ai-releases/index.astro` | Index page listing all monthly editions |
| Create | `apps/marketing/src/pages/open-source-ai-releases/[...id].astro` | Dynamic page rendering each monthly edition |
| Create | `apps/marketing/src/layouts/ReleasesLayout.astro` | Layout for monthly release pages (structured data, hero, FAQ) |
| Modify | `apps/marketing/astro.config.mjs` | Add releases to sitemap date map + sitemap chunk |
| Modify | `apps/marketing/src/content/blog/best-open-source-ai-coding-tools-2026.md` | Update `updatedDate`, add callout |

---

### Task 1: Add `releases` content collection

**Files:**
- Modify: `apps/marketing/src/content.config.ts`

- [ ] **Step 1: Add the releases collection schema**

In `apps/marketing/src/content.config.ts`, add a new `releases` collection after the `lighthouse` collection (around line 58). The schema matches the spec: title, description, month, year, pubDate, updatedDate, image, faq.

```typescript
const releases = defineCollection({
	loader: glob({ pattern: '**/*.md', base: './src/content/releases' }),
	schema: () =>
		z.object({
			title: z.string(),
			description: z.string(),
			month: z.string(),
			year: z.number(),
			pubDate: z.date(),
			updatedDate: z.date().optional(),
			image: z.string().optional(),
			faq: z
				.array(
					z.object({
						question: z.string(),
						answer: z.string()
					})
				)
				.optional()
		})
})
```

- [ ] **Step 2: Register the collection in the exports**

Change the `collections` export (around line 65) from:

```typescript
export const collections = {
	blog,
	lighthouse,
	docs,
}
```

To:

```typescript
export const collections = {
	blog,
	lighthouse,
	releases,
	docs,
}
```

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/src/content.config.ts
git commit -m "feat(marketing): add releases content collection schema"
```

---

### Task 2: Create seed content — March 2026

**Files:**
- Create: `apps/marketing/src/content/releases/march-2026.md`

- [ ] **Step 1: Create the content directory**

```bash
mkdir -p apps/marketing/src/content/releases
```

- [ ] **Step 2: Write the March 2026 markdown file**

Create `apps/marketing/src/content/releases/march-2026.md` with this content:

```markdown
---
title: 'New Open Source AI Releases — March 2026'
description: 'Notable open-source AI projects released in March 2026. Curated picks with context on what shipped and why it matters.'
month: 'March'
year: 2026
pubDate: 2026-03-31T00:00:00Z
faq:
  - question: 'What open source AI projects were released in March 2026?'
    answer: 'March 2026 saw major releases across the open-source AI coding space. Aider shipped v0.82 with improved repo mapping for large monorepos. Goose reached v1.0 with a stable desktop app and MCP plugin marketplace. Roo Code added JetBrains support in beta. OpenHands launched a free cloud tier with Minimax models. Kilo Code crossed 1.5 million users and became the top consumer on OpenRouter.'
  - question: 'What are the newest open source AI tools in March 2026?'
    answer: 'The newest entrants in March 2026 include several MCP-based tools and agent frameworks. Goose v1.0 was the biggest release with its stable desktop app. Most activity was updates to existing tools rather than brand-new projects, with Aider, Roo Code, Cline, and OpenHands all shipping significant versions.'
---

March was a month of consolidation in the open-source AI coding space. The big projects shipped stability updates rather than flashy new features, and the ecosystem around MCP continued to expand.

## Goose v1.0 — Stable Desktop App

[block.github.io/goose](https://block.github.io/goose) | Apache-2.0

Block shipped the v1.0 milestone for Goose, marking its desktop app as stable. The MCP plugin marketplace now has 50+ community extensions. The desktop app makes Goose the most accessible CLI-style agent — you get terminal power with a GUI fallback.

## Aider v0.82 — Better Monorepo Support

[aider.chat](https://aider.chat) | Apache-2.0

Aider's repo mapping, which scans your codebase to give the LLM context, previously hit memory limits on very large monorepos. v0.82 introduces chunked mapping that handles repos with 100k+ files. Also adds experimental multi-model support for using different models for different tasks within a single session.

## Roo Code — JetBrains Beta

[roocode.com](https://roocode.com) | Apache-2.0

Roo Code expanded beyond VS Code with a JetBrains plugin in beta. This puts it in direct competition with Kilo Code, which already supported JetBrains. The multi-mode system (Code, Architect, Ask, Debug) now works across both IDEs.

## OpenHands Free Cloud Tier

[openhands.dev](https://openhands.dev) | MIT

OpenHands launched a free tier of their hosted platform using Minimax models. Previously you needed your own API key or a paid plan. The free tier is limited but gives a zero-friction way to try autonomous AI development.

## Kilo Code — 1.5 Million Users

[github.com/Kilo-Org/kilocode](https://github.com/Kilo-Org/kilocode) | Apache-2.0

Kilo Code reported crossing 1.5 million users and becoming the highest-volume consumer on OpenRouter. For a Cline fork that launched less than a year ago, the growth rate is notable. JetBrains support remains its main differentiator from the parent project.

## Frontman — Astro + Vite Support

[frontman.sh](https://frontman.sh) | Apache-2.0 / AGPL-3.0

*Disclosure: We built this.* Frontman added Astro and Vite framework integrations alongside the existing Next.js support. The browser-based approach now works across the three most popular frontend build tools.

---

For a detailed comparison of all major open-source AI coding tools, see our [full comparison guide](/blog/best-open-source-ai-coding-tools-2026/).
```

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/src/content/releases/march-2026.md
git commit -m "content(marketing): add March 2026 releases roundup"
```

---

### Task 3: Create seed content — April 2026

**Files:**
- Create: `apps/marketing/src/content/releases/april-2026.md`

- [ ] **Step 1: Write the April 2026 markdown file**

Create `apps/marketing/src/content/releases/april-2026.md` with this content:

```markdown
---
title: 'New Open Source AI Releases — April 2026'
description: 'Notable open-source AI projects released in April 2026. Curated picks with context on what shipped and why it matters.'
month: 'April'
year: 2026
pubDate: 2026-04-06T00:00:00Z
faq:
  - question: 'What open source AI projects were released in April 2026?'
    answer: 'April 2026 is still early, but notable releases so far include Cline v3.5 with improved multi-file editing workflows, Continue shipping its first stable CI-focused release after the pivot from IDE extension, and Stagewise expanding its IDE agent bridge to support Windsurf and Roo Code alongside Cursor and Copilot.'
  - question: 'What are the newest open source AI tools in April 2026?'
    answer: 'The biggest theme in early April 2026 is tool convergence — established projects are adding features that overlap with competitors. Cline is borrowing multi-mode ideas from Roo Code, Continue is moving fully into CI/CD territory, and browser-based tools like Stagewise and Frontman are expanding framework coverage.'
---

Early April — this page will be updated throughout the month as releases ship.

## Cline v3.5 — Multi-File Editing

[github.com/cline/cline](https://github.com/cline/cline) | Apache-2.0

Cline v3.5 improves multi-file editing with a new diff preview that shows all pending changes across files before you approve. Previously, each file edit was approved individually. The batch approval workflow reduces friction for larger refactors.

## Continue — First Stable CI Release

[docs.continue.dev](https://docs.continue.dev) | Apache-2.0

Continue shipped v1.0 of its CI tool after pivoting away from IDE-first development. The tool runs AI-powered code review checks in your CI pipeline — think linting but with LLM-based semantic analysis. Early reports suggest it catches logic issues that traditional linters miss, but adds 30-60 seconds to pipeline runs.

## Stagewise — Expanded IDE Bridge

[stagewise.io](https://stagewise.io) | AGPL-3.0

Stagewise added Windsurf and Roo Code to its IDE agent bridge, joining Cursor and Copilot. The bridge lets you click elements in the browser toolbar and route the edit through your preferred IDE agent. The broader bridge support makes it a more viable option for teams that aren't on Cursor.

---

For a detailed comparison of all major open-source AI coding tools, see our [full comparison guide](/blog/best-open-source-ai-coding-tools-2026/).
```

- [ ] **Step 2: Commit**

```bash
git add apps/marketing/src/content/releases/april-2026.md
git commit -m "content(marketing): add April 2026 releases roundup"
```

---

### Task 4: Create the ReleasesLayout

**Files:**
- Create: `apps/marketing/src/layouts/ReleasesLayout.astro`

This layout handles structured data (ItemList, FAQPage) and page chrome for monthly release pages. It follows the same patterns as `PostLayout.astro`.

- [ ] **Step 1: Create the layout file**

Create `apps/marketing/src/layouts/ReleasesLayout.astro`:

```astro
---
const { frontmatter, body } = Astro.props

import Layout from './Layout.astro'
import BlogPostHero from '../components/blocks/blog/BlogPostHero.astro'

const SEO = {
	title: `${frontmatter.title} | Frontman`,
	description: frontmatter.description
}

const pubDateISO = frontmatter.pubDate instanceof Date ? frontmatter.pubDate.toISOString() : frontmatter.pubDate
const updatedDateISO = frontmatter.updatedDate instanceof Date ? frontmatter.updatedDate.toISOString() : frontmatter.updatedDate

const wordCount = body
	? body.replace(/```[\s\S]*?```/g, '').replace(/[#*_\[\]()>|`~-]/g, '').split(/\s+/).filter(Boolean).length
	: undefined

// WebPage JSON-LD with dateModified for freshness signals
const webPageJsonLd = {
	"@context": "https://schema.org",
	"@type": "WebPage",
	"name": frontmatter.title,
	"description": frontmatter.description,
	"url": Astro.url.href,
	"datePublished": pubDateISO,
	...(updatedDateISO ? { "dateModified": updatedDateISO } : { "dateModified": pubDateISO }),
	...(wordCount ? { "wordCount": wordCount } : {}),
	"publisher": {
		"@type": "Organization",
		"name": "Frontman",
		"logo": {
			"@type": "ImageObject",
			"url": "https://frontman.sh/logo.svg"
		}
	},
	"mainEntityOfPage": {
		"@type": "WebPage",
		"@id": Astro.url.href
	}
}

// FAQPage JSON-LD (optional)
const faqJsonLd = frontmatter.faq?.length
	? {
			"@context": "https://schema.org",
			"@type": "FAQPage",
			"mainEntity": frontmatter.faq.map((item: { question: string; answer: string }) => ({
				"@type": "Question",
				"name": item.question,
				"acceptedAnswer": {
					"@type": "Answer",
					"text": item.answer
				}
			}))
		}
	: null
---

<Layout
	title={SEO.title}
	description={SEO.description}
	ogImage={frontmatter.image}
>
	<script is:inline type="application/ld+json" set:html={JSON.stringify(webPageJsonLd)} />
	{faqJsonLd && <script is:inline type="application/ld+json" set:html={JSON.stringify(faqJsonLd)} />}
	<BlogPostHero
		title={frontmatter.title}
		pubDate={frontmatter.pubDate}
		updatedDate={frontmatter.updatedDate}
	/>

	<div class="post-body basic-text basic-text--lg">
		<slot />
	</div>

	{frontmatter.faq?.length && (
		<section class="post-faq">
			<div class="post-faq__container">
				<h2 class="post-faq__title">Frequently Asked Questions</h2>
				<div class="post-faq__list">
					{frontmatter.faq.map((item: { question: string; answer: string }) => (
						<details class="post-faq__item group">
							<summary class="post-faq__question">
								<span>{item.question}</span>
								<span class="post-faq__icon">+</span>
							</summary>
							<div class="post-faq__answer">
								<p>{item.answer}</p>
							</div>
						</details>
					))}
				</div>
			</div>
		</section>
	)}
</Layout>

<style>
	@reference "../styles/global.css";
	.post-body {
		@apply mx-auto max-w-3xl px-6 py-12 lg:py-24;
	}

	.post-faq {
		background: #09090b;
		color: #fafafa;
		padding: 64px 24px;
		display: flex;
		justify-content: center;
	}
	.post-faq__container {
		max-width: 720px;
		width: 100%;
	}
	.post-faq__title {
		font-size: 32px;
		font-weight: 700;
		color: #fafafa;
		margin-bottom: 24px;
		letter-spacing: -0.02em;
	}
	.post-faq__list {
		border-top: 1px solid #27272a;
	}
	.post-faq__item {
		border-bottom: 1px solid #27272a;
		cursor: pointer;
	}
	.post-faq__question {
		width: 100%;
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 24px 0;
		color: #fafafa;
		font-size: 17px;
		font-weight: 500;
		line-height: 1.4;
		list-style: none;
		transition: color 0.2s;
	}
	.post-faq__question::-webkit-details-marker { display: none; }
	.post-faq__question:hover { color: #fff; }
	.post-faq__question span:first-child { padding-right: 24px; }
	.post-faq__icon {
		flex-shrink: 0;
		width: 28px;
		height: 28px;
		border-radius: 50%;
		border: 1px solid #3f3f46;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 18px;
		font-weight: 300;
		color: #71717a;
		transition: all 0.3s ease;
	}
	.group[open] .post-faq__icon {
		transform: rotate(45deg);
		background: #27272a;
	}
	.post-faq__answer p {
		font-size: 15px;
		line-height: 1.7;
		color: #a1a1aa;
		padding-bottom: 24px;
		margin: 0;
		max-width: 620px;
	}

	@media (max-width: 768px) {
		.post-faq { padding: 40px 20px; }
		.post-faq__title { font-size: 24px; }
	}
</style>
```

- [ ] **Step 2: Commit**

```bash
git add apps/marketing/src/layouts/ReleasesLayout.astro
git commit -m "feat(marketing): add ReleasesLayout for monthly release pages"
```

---

### Task 5: Create the monthly release dynamic page

**Files:**
- Create: `apps/marketing/src/pages/open-source-ai-releases/[...id].astro`

This follows the exact same pattern as `apps/marketing/src/pages/blog/[...id].astro`.

- [ ] **Step 1: Create the directory**

```bash
mkdir -p apps/marketing/src/pages/open-source-ai-releases
```

- [ ] **Step 2: Create the dynamic page**

Create `apps/marketing/src/pages/open-source-ai-releases/[...id].astro`:

```astro
---
import Layout from '../../layouts/ReleasesLayout.astro'
import { getCollection, render } from 'astro:content'

export async function getStaticPaths() {
	const entries = await getCollection('releases')
	return entries.map((entry) => ({
		params: { id: decodeURI(entry.id) },
		props: { entry }
	}))
}

const { entry } = Astro.props
const { Content } = await render(entry)
---

<Layout frontmatter={entry.data} body={entry.body}>
	<Content />
</Layout>
```

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/src/pages/open-source-ai-releases/
git commit -m "feat(marketing): add dynamic route for monthly release pages"
```

---

### Task 6: Create the releases index page

**Files:**
- Create: `apps/marketing/src/pages/open-source-ai-releases/index.astro`

Follows the pattern of `apps/marketing/src/pages/blog/index.astro`.

- [ ] **Step 1: Create the index page**

Create `apps/marketing/src/pages/open-source-ai-releases/index.astro`:

```astro
---
import Layout from '../../layouts/Layout.astro'
import Hero from '../../components/blocks/hero/PageHeader.astro'
import { getCollection } from 'astro:content'

const SEO = {
	title: 'Open Source AI Releases — Monthly Roundups | Frontman',
	description:
		'Monthly curated roundups of notable open-source AI project releases. New tools, major updates, and emerging projects.'
}

const header = {
	title: 'Open Source AI Releases',
	text: 'Monthly curated roundups of notable open-source AI project releases.'
}

const allReleases = await getCollection('releases')

const sortedReleases = [...allReleases].sort((a, b) => {
	if (b.data.year !== a.data.year) return b.data.year - a.data.year
	return new Date(b.data.pubDate).getTime() - new Date(a.data.pubDate).getTime()
})

// CollectionPage + ItemList JSON-LD
const collectionJsonLd = {
	"@context": "https://schema.org",
	"@type": "CollectionPage",
	"name": "Open Source AI Releases — Monthly Roundups",
	"description": SEO.description,
	"url": "https://frontman.sh/open-source-ai-releases/",
	"mainEntity": {
		"@type": "ItemList",
		"itemListElement": sortedReleases.map((entry, index) => ({
			"@type": "ListItem",
			"position": index + 1,
			"name": entry.data.title,
			"url": `https://frontman.sh/open-source-ai-releases/${entry.id}/`
		}))
	}
}
---

<Layout title={SEO.title} description={SEO.description}>
	<script is:inline type="application/ld+json" set:html={JSON.stringify(collectionJsonLd)} />
	<Hero title={header.title} text={header.text} />

	<section class="releases-list">
		<div class="releases-list__container">
			{sortedReleases.map((entry) => (
				<a href={`/open-source-ai-releases/${entry.id}/`} class="releases-list__item">
					<div class="releases-list__meta">
						<span class="releases-list__date">{entry.data.month} {entry.data.year}</span>
					</div>
					<h2 class="releases-list__title">{entry.data.title}</h2>
					<p class="releases-list__description">{entry.data.description}</p>
				</a>
			))}
		</div>

		<div class="releases-list__cta">
			<p>For a detailed comparison of all major tools, see our <a href="/blog/best-open-source-ai-coding-tools-2026/">full open-source AI coding tools comparison</a>.</p>
		</div>
	</section>
</Layout>

<style>
	@reference "../../styles/global.css";
	.releases-list {
		@apply mx-auto max-w-3xl px-6 py-12 lg:py-24;
	}
	.releases-list__container {
		@apply flex flex-col gap-6;
	}
	.releases-list__item {
		@apply block rounded-lg border border-neutral-200 dark:border-neutral-800 p-6 no-underline transition-colors hover:border-primary-500 dark:hover:border-primary-400;
	}
	.releases-list__meta {
		@apply mb-2;
	}
	.releases-list__date {
		@apply text-sm font-medium text-primary-600 dark:text-primary-400;
	}
	.releases-list__title {
		@apply text-xl font-semibold text-neutral-900 dark:text-neutral-100 mb-2;
	}
	.releases-list__description {
		@apply text-base text-neutral-600 dark:text-neutral-400 leading-relaxed m-0;
	}
	.releases-list__cta {
		@apply mt-12 text-center text-neutral-600 dark:text-neutral-400;
	}
	.releases-list__cta a {
		@apply text-primary-600 dark:text-primary-400 hover:underline;
	}
</style>
```

- [ ] **Step 2: Commit**

```bash
git add apps/marketing/src/pages/open-source-ai-releases/index.astro
git commit -m "feat(marketing): add releases index page with CollectionPage schema"
```

---

### Task 7: Add releases to sitemap config

**Files:**
- Modify: `apps/marketing/astro.config.mjs`

- [ ] **Step 1: Add releases date map**

In `apps/marketing/astro.config.mjs`, after line 29 (`const blogDateMap = ...`), add:

```javascript
const releasesDateMap = buildDateMap(path.resolve(appRoot, "src/content/releases"));
```

- [ ] **Step 2: Add releases to the sitemap serialize function**

In the `serialize` callback (around line 195), add a releases matcher after the lighthouse matcher. Change this block:

```javascript
      const blogMatch = item.url.match(/\/blog\/([^/]+)\/?$/);
      const lighthouseMatch = item.url.match(/\/lighthouse\/([^/]+)\/?$/);
      if (blogMatch && blogDateMap.has(blogMatch[1])) {
        item.lastmod = blogDateMap.get(blogMatch[1]);
      } else if (lighthouseMatch && lighthouseDateMap.has(lighthouseMatch[1])) {
        item.lastmod = lighthouseDateMap.get(lighthouseMatch[1]);
      } else {
```

To:

```javascript
      const blogMatch = item.url.match(/\/blog\/([^/]+)\/?$/);
      const lighthouseMatch = item.url.match(/\/lighthouse\/([^/]+)\/?$/);
      const releasesMatch = item.url.match(/\/open-source-ai-releases\/([^/]+)\/?$/);
      if (blogMatch && blogDateMap.has(blogMatch[1])) {
        item.lastmod = blogDateMap.get(blogMatch[1]);
      } else if (lighthouseMatch && lighthouseDateMap.has(lighthouseMatch[1])) {
        item.lastmod = lighthouseDateMap.get(lighthouseMatch[1]);
      } else if (releasesMatch && releasesDateMap.has(releasesMatch[1])) {
        item.lastmod = releasesDateMap.get(releasesMatch[1]);
      } else {
```

- [ ] **Step 3: Add releases sitemap chunk**

In the `chunks` object (around line 212), add a `releases` chunk after `comparisons`:

```javascript
      releases: (item) => {
        if (/\/open-source-ai-releases\//.test(item.url)) return item;
      },
```

- [ ] **Step 4: Commit**

```bash
git add apps/marketing/astro.config.mjs
git commit -m "feat(marketing): add releases to sitemap date map and chunks"
```

---

### Task 8: Update existing comparison post

**Files:**
- Modify: `apps/marketing/src/content/blog/best-open-source-ai-coding-tools-2026.md`

- [ ] **Step 1: Update `updatedDate` in frontmatter**

Change line 8 from:

```yaml
updatedDate: 2026-03-10T00:00:00Z
```

To:

```yaml
updatedDate: 2026-04-06T00:00:00Z
```

- [ ] **Step 2: Add callout linking to releases page**

After line 22 (the intro paragraph ending with "...organized by architecture category. We built Frontman (one of the tools listed), so we'll note that where relevant and call out where other tools are stronger."), add:

```markdown

> **Looking for the latest releases?** See our [monthly open source AI releases roundup](/open-source-ai-releases/) for what shipped recently.
```

- [ ] **Step 3: Update the "Last updated" line**

Change line 24 from:

```markdown
Last updated: March 2026. Star counts are approximate.
```

To:

```markdown
Last updated: April 2026. Star counts are approximate.
```

- [ ] **Step 4: Commit**

```bash
git add apps/marketing/src/content/blog/best-open-source-ai-coding-tools-2026.md
git commit -m "fix(marketing): update comparison post with releases cross-link and fresh date"
```

---

### Task 9: Build verification

- [ ] **Step 1: Run the Astro build to verify everything compiles**

```bash
cd apps/marketing && npx astro build
```

Expected: Build succeeds with no errors. The output should include the new routes:
- `/open-source-ai-releases/index.html`
- `/open-source-ai-releases/march-2026/index.html`
- `/open-source-ai-releases/april-2026/index.html`

- [ ] **Step 2: Verify structured data in build output**

```bash
grep -l "CollectionPage" dist/open-source-ai-releases/index.html
grep -l "FAQPage" dist/open-source-ai-releases/march-2026/index.html
grep -l "WebPage" dist/open-source-ai-releases/march-2026/index.html
```

Expected: All three greps return the file path (confirming JSON-LD is present).

- [ ] **Step 3: Verify sitemap includes releases**

```bash
grep "open-source-ai-releases" dist/sitemap-releases-0.xml
```

Expected: Shows URLs for both monthly pages and the index.

- [ ] **Step 4: Verify the comparison post callout**

```bash
grep "monthly open source AI releases roundup" dist/blog/best-open-source-ai-coding-tools-2026/index.html
```

Expected: Returns the line with the callout link.
