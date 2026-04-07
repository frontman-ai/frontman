# SEO Comparison Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a shared `ComparisonLayout.astro` with new SEO components and refactor `/vs/cursor/` as the template page.

**Architecture:** Shared layout + named slots pattern. `ComparisonLayout.astro` handles common structure (hero, feature table, pricing, FAQ, CTA, structured data). Each competitor page passes data as props and fills slots with unique prose. New components: `ComparisonAlternatives`, `ComparisonArchitectureDiagram`, `ComparisonFAQ`, `ComparisonStructuredData`.

**Tech Stack:** Astro, Tailwind CSS (utility classes only, no scoped `<style>` blocks), JSON-LD structured data.

**Spec:** `docs/superpowers/specs/2026-04-07-seo-comparison-pages-design.md`

---

### Task 1: Create ComparisonFAQ.astro (Tailwind)

Extract the FAQ accordion into a standalone Tailwind component, replacing the scoped-style `IntegrationFAQ.astro` pattern used by newer pages and the inline FAQ in cursor.astro.

**Files:**
- Create: `apps/marketing/src/components/blocks/comparison/ComparisonFAQ.astro`

- [ ] **Step 1: Create the component**

```astro
---
// ComparisonFAQ
// -------------
// FAQ accordion section for /vs/ comparison pages.
// Tailwind utility classes only — no scoped <style> block.

type FAQ = {
  question: string
  answer: string
}

type Props = {
  faqs: FAQ[]
}

const { faqs } = Astro.props
---

<section class="flex justify-center bg-zinc-950 px-6 py-16 text-zinc-50 max-md:px-5 max-md:py-10">
  <div class="w-full max-w-[720px]">
    <h2 class="mb-6 text-[32px] font-bold tracking-tight text-zinc-50 max-md:text-2xl">Frequently Asked Questions</h2>
    <div class="border-t border-zinc-800">
      {faqs.map((faq) => (
        <details class="group border-b border-zinc-800 cursor-pointer">
          <summary class="flex w-full items-center justify-between py-6 text-[17px] font-medium leading-[1.4] text-zinc-50 transition-colors [&::-webkit-details-marker]:hidden hover:text-white list-none">
            <span class="pr-6">{faq.question}</span>
            <span class="flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-zinc-700 text-lg font-light text-zinc-500 transition-all duration-300 group-open:rotate-45 group-open:bg-zinc-800">+</span>
          </summary>
          <div class="max-w-[620px] pb-6 text-[15px] leading-[1.7] text-zinc-400">
            <p>{faq.answer}</p>
          </div>
        </details>
      ))}
    </div>
  </div>
</section>
```

- [ ] **Step 2: Verify build**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Build succeeds (component isn't imported yet, just checking for syntax errors in the overall build).

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/src/components/blocks/comparison/ComparisonFAQ.astro
git commit -m "feat(marketing): add ComparisonFAQ component with Tailwind"
```

---

### Task 2: Create ComparisonAlternatives.astro

New component targeting "[competitor] alternatives" search queries. Grid of cards linking to other `/vs/` pages.

**Files:**
- Create: `apps/marketing/src/components/blocks/comparison/ComparisonAlternatives.astro`

- [ ] **Step 1: Create the component**

```astro
---
// ComparisonAlternatives
// ----------------------
// Targets "[competitor] alternatives" search queries.
// Shows a grid of cards linking to other /vs/ pages.
// Tailwind utility classes only.

type Alternative = {
  name: string
  slug: string
  oneLiner: string
}

type Props = {
  competitorName: string
  alternatives: Alternative[]
}

const { competitorName, alternatives } = Astro.props
---

<section class="flex justify-center bg-zinc-950 px-6 py-16 text-zinc-50 max-md:px-5 max-md:py-10">
  <div class="w-full max-w-[720px]">
    <h2 class="mb-3 text-[32px] font-bold tracking-tight text-zinc-50 max-md:text-2xl">{competitorName} Alternatives</h2>
    <p class="mb-8 text-[17px] leading-[1.7] text-zinc-400">
      If {competitorName} isn't the right fit, here are other tools worth evaluating — and how they compare to Frontman.
    </p>
    <div class="grid gap-4 sm:grid-cols-2">
      {alternatives.map((alt) => {
        const isFrontman = alt.slug === ''
        return (
          <a
            href={isFrontman ? '/' : `/vs/${alt.slug}/`}
            class:list={[
              'block rounded-2xl border p-6 transition-colors',
              isFrontman
                ? 'border-primary-500/40 bg-primary-500/[0.08] hover:border-primary-500/60'
                : 'border-white/[0.08] bg-white/[0.04] hover:border-white/20',
            ]}
          >
            <h3 class:list={[
              'mb-1 text-base font-bold',
              isFrontman ? 'text-primary-500' : 'text-zinc-50',
            ]}>
              {isFrontman ? 'Frontman' : `Frontman vs ${alt.name}`}
            </h3>
            <p class="text-sm leading-relaxed text-zinc-400">{alt.oneLiner}</p>
          </a>
        )
      })}
    </div>
  </div>
</section>
```

- [ ] **Step 2: Verify build**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/src/components/blocks/comparison/ComparisonAlternatives.astro
git commit -m "feat(marketing): add ComparisonAlternatives component for SEO"
```

---

### Task 3: Create ComparisonArchitectureDiagram.astro

Simple wrapper that renders a per-page SVG diagram comparing architectural approaches.

**Files:**
- Create: `apps/marketing/src/components/blocks/comparison/ComparisonArchitectureDiagram.astro`

- [ ] **Step 1: Create the component**

```astro
---
// ComparisonArchitectureDiagram
// -----------------------------
// Renders an inline SVG diagram comparing how Frontman and a competitor work.
// The SVG is defined per-page and passed as a string prop.
// Tailwind utility classes only.

type Props = {
  competitorName: string
}

const { competitorName } = Astro.props
---

<section class="flex justify-center bg-zinc-950 px-6 py-16 text-zinc-50 max-md:px-5 max-md:py-10">
  <div class="w-full max-w-[900px]">
    <h2 class="mb-8 text-[32px] font-bold tracking-tight text-zinc-50 max-md:text-2xl">How Frontman and {competitorName} Work</h2>
    <div class="flex justify-center rounded-2xl border border-white/[0.08] bg-white/[0.02] p-8 max-md:p-4">
      <slot />
    </div>
  </div>
</section>
```

Note: The SVG content is passed via the default slot instead of a string prop. This is cleaner in Astro — the per-page file writes the SVG inline inside the component tags. Updated from spec (slot is better than `set:html` for this — avoids XSS concerns and works with Astro's compiler).

- [ ] **Step 2: Verify build**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/src/components/blocks/comparison/ComparisonArchitectureDiagram.astro
git commit -m "feat(marketing): add ComparisonArchitectureDiagram component"
```

---

### Task 4: Create ComparisonStructuredData.astro

Centralizes all JSON-LD for comparison pages: FAQPage, SoftwareApplication (both tools), and WebPage.

**Files:**
- Create: `apps/marketing/src/components/blocks/comparison/ComparisonStructuredData.astro`

- [ ] **Step 1: Create the component**

```astro
---
// ComparisonStructuredData
// ------------------------
// Emits all JSON-LD structured data for a /vs/ comparison page.
// Blocks: FAQPage, SoftwareApplication (Frontman), SoftwareApplication (competitor), WebPage.

type FAQ = {
  question: string
  answer: string
}

type CompetitorInfo = {
  name: string
  url: string
  category: string
  description: string
  pricing: {
    cost: string
    model: string
  }
}

type SEOInfo = {
  title: string
  description: string
}

type Props = {
  competitor: CompetitorInfo
  faqs: FAQ[]
  seo: SEOInfo
}

const { competitor, faqs, seo } = Astro.props
const pageUrl = Astro.url.href

// FAQPage
const faqJsonLd = {
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": faqs.map((faq) => ({
    "@type": "Question",
    "name": faq.question,
    "acceptedAnswer": {
      "@type": "Answer",
      "text": faq.answer,
    },
  })),
}

// SoftwareApplication — Frontman
const frontmanAppJsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "Frontman",
  "url": "https://frontman.sh/",
  "applicationCategory": "DesignApplication",
  "operatingSystem": "Web",
  "description": "An open-source AI agent that lets designers and product managers edit a running app in the browser. Point at any element, describe the change, get real code.",
  "license": "https://github.com/frontman-ai/frontman/blob/main/LICENSE",
  "codeRepository": "https://github.com/frontman-ai/frontman",
  "offers": {
    "@type": "Offer",
    "price": "0",
    "priceCurrency": "USD",
    "description": "Free and open source — bring your own API key",
  },
  "isSimilarTo": {
    "@type": "SoftwareApplication",
    "name": competitor.name,
    "url": competitor.url,
  },
}

// SoftwareApplication — Competitor
const competitorAppJsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": competitor.name,
  "url": competitor.url,
  "applicationCategory": competitor.category,
  "description": competitor.description,
  "offers": {
    "@type": "Offer",
    "price": competitor.pricing.cost,
    "priceCurrency": "USD",
    "description": competitor.pricing.model,
  },
}

// WebPage
const webPageJsonLd = {
  "@context": "https://schema.org",
  "@type": "WebPage",
  "name": seo.title,
  "description": seo.description,
  "url": pageUrl,
  "reviewedBy": {
    "@type": "Organization",
    "name": "Frontman",
    "url": "https://frontman.sh/",
  },
}
---

<script is:inline type="application/ld+json" set:html={JSON.stringify(faqJsonLd)} />
<script is:inline type="application/ld+json" set:html={JSON.stringify(frontmanAppJsonLd)} />
<script is:inline type="application/ld+json" set:html={JSON.stringify(competitorAppJsonLd)} />
<script is:inline type="application/ld+json" set:html={JSON.stringify(webPageJsonLd)} />
```

- [ ] **Step 2: Verify build**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/src/components/blocks/comparison/ComparisonStructuredData.astro
git commit -m "feat(marketing): add ComparisonStructuredData with Product schema"
```

---

### Task 5: Create ComparisonContentSection.astro (Tailwind)

A Tailwind-only version of `IntegrationContentSection.astro` for comparison pages. Needed by the layout for prose slot wrappers.

**Files:**
- Create: `apps/marketing/src/components/blocks/comparison/ComparisonContentSection.astro`

- [ ] **Step 1: Create the component**

```astro
---
// ComparisonContentSection
// ------------------------
// Prose content wrapper for /vs/ comparison pages.
// Tailwind utility classes only — replaces IntegrationContentSection for comparison use.

type Props = {
  title: string
  variant?: 'dark' | 'light'
}

const { title, variant = 'dark' } = Astro.props
const isLight = variant === 'light'
---

<section class:list={[
  'flex justify-center px-6 py-16 max-md:px-5 max-md:py-10',
  isLight ? 'bg-zinc-50 text-zinc-950' : 'bg-zinc-950 text-zinc-50',
]}>
  <div class="w-full max-w-[720px]">
    <h2 class:list={[
      'mb-6 text-[32px] font-bold tracking-tight max-md:text-2xl',
      isLight ? 'text-zinc-950' : 'text-zinc-50',
    ]}>{title}</h2>
    <div class:list={[
      '[&_p]:mb-4 [&_p]:text-[17px] [&_p]:leading-[1.7]',
      isLight
        ? '[&_p]:text-zinc-600 [&_strong]:text-zinc-950 [&_li]:text-zinc-600 [&_li_strong]:text-zinc-950 [&_code]:bg-black/[0.06] [&_.text-link]:text-violet-700 [&_.text-link:hover]:text-violet-800'
        : '[&_p]:text-zinc-400 [&_strong]:text-zinc-50 [&_li]:text-zinc-400 [&_li_strong]:text-zinc-50 [&_code]:bg-white/[0.08] [&_.text-link]:text-primary-500 [&_.text-link:hover]:text-purple-400',
      '[&_strong]:font-semibold',
      '[&_code]:rounded [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:font-mono [&_code]:text-sm',
      '[&_ul]:my-4 [&_ul]:list-none [&_ul]:p-0',
      '[&_li]:relative [&_li]:py-2 [&_li]:pl-6 [&_li]:text-[17px] [&_li]:leading-[1.7]',
      "[&_li]:before:absolute [&_li]:before:left-0 [&_li]:before:top-[18px] [&_li]:before:h-2 [&_li]:before:w-2 [&_li]:before:rounded-full [&_li]:before:bg-primary-500 [&_li]:before:content-['']",
    ]}>
      <slot />
    </div>
  </div>
</section>
```

- [ ] **Step 2: Verify build**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/src/components/blocks/comparison/ComparisonContentSection.astro
git commit -m "feat(marketing): add ComparisonContentSection with Tailwind"
```

---

### Task 6: Migrate ComparisonFeatureTable.astro to Tailwind

Convert the existing scoped `<style>` block to Tailwind utility classes.

**Files:**
- Modify: `apps/marketing/src/components/blocks/comparison/ComparisonFeatureTable.astro`

- [ ] **Step 1: Read the current file**

Read `apps/marketing/src/components/blocks/comparison/ComparisonFeatureTable.astro` to get the exact current content.

- [ ] **Step 2: Rewrite with Tailwind classes**

Replace the entire file with:

```astro
---
// ComparisonFeatureTable
// ----------------------
// Shared feature comparison table for /vs/ pages.
// Tailwind utility classes only.

type Status = 'yes' | 'no' | 'partial'

export type ComparisonFeature = {
  name: string
  frontman: Status
  competitor: Status
  frontmanNote?: string
  competitorNote?: string
}

type Props = {
  competitorName: string
  features: ComparisonFeature[]
}

const { competitorName, features } = Astro.props

function statusLabel(status: Status): string {
  switch (status) {
    case 'yes': return 'Yes'
    case 'no': return 'No'
    case 'partial': return 'Partial'
  }
}
---

<section class="flex justify-center bg-zinc-950 px-6 py-16 max-md:px-5 max-md:py-10">
  <div class="w-full max-w-[900px]">
    <h2 class="mb-8 text-[32px] font-bold tracking-tight text-zinc-50 max-md:text-2xl">Feature Comparison</h2>

    <!-- Desktop table -->
    <div class="hidden md:block">
      <table class="w-full border-separate border-spacing-0" role="grid">
        <thead>
          <tr>
            <th class="border-b border-white/10 px-6 py-4 text-left text-sm font-semibold uppercase tracking-wider text-white/40">Feature</th>
            <th class="w-60 border-b border-primary-500/20 border-t-[3px] border-t-primary-500 bg-primary-500/[0.08] px-6 py-4 text-center text-base font-bold text-primary-500">Frontman</th>
            <th class="w-60 border-b border-white/10 px-6 py-4 text-center text-base font-bold text-white/70">{competitorName}</th>
          </tr>
        </thead>
        <tbody>
          {features.map((feature, i) => {
            const isLast = i === features.length - 1
            return (
              <tr>
                <td class:list={['px-6 py-4 text-left text-base text-white/90', !isLast && 'border-b border-white/[0.06]']}>{feature.name}</td>
                <td class:list={['bg-primary-500/[0.08] px-6 py-4', !isLast && 'border-b border-white/[0.06]']} aria-label={statusLabel(feature.frontman)}>
                  <div class="flex items-center gap-2">
                    {feature.frontman === 'yes' && <svg class="inline-block text-green-500" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>}
                    {feature.frontman === 'no' && <svg class="inline-block text-red-500" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>}
                    {feature.frontman === 'partial' && <svg class="inline-block text-amber-500" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"></line></svg>}
                    {feature.frontmanNote && <span class="text-[13px] text-white/50">{feature.frontmanNote}</span>}
                  </div>
                </td>
                <td class:list={['px-6 py-4', !isLast && 'border-b border-white/[0.06]']} aria-label={statusLabel(feature.competitor)}>
                  <div class="flex items-center gap-2">
                    {feature.competitor === 'yes' && <svg class="inline-block text-green-500" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>}
                    {feature.competitor === 'no' && <svg class="inline-block text-red-500" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>}
                    {feature.competitor === 'partial' && <svg class="inline-block text-amber-500" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"></line></svg>}
                    {feature.competitorNote && <span class="text-[13px] text-white/50">{feature.competitorNote}</span>}
                  </div>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>

    <!-- Mobile cards -->
    <div class="flex flex-col gap-3 md:hidden">
      {features.map((feature) => (
        <div class="rounded-xl border border-white/[0.08] bg-white/[0.04] p-4">
          <h3 class="font-headings mb-3 text-sm font-bold text-white">{feature.name}</h3>
          <div class="grid grid-cols-2 gap-3">
            <div class="flex items-center justify-between rounded-lg border border-primary-500/25 bg-primary-500/[0.12] px-3 py-2">
              <span class="text-sm font-semibold text-primary-500">Frontman</span>
              <span>
                {feature.frontman === 'yes' && <svg class="inline-block text-green-500" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>}
                {feature.frontman === 'no' && <svg class="inline-block text-red-500" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>}
                {feature.frontman === 'partial' && <svg class="inline-block text-amber-500" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"></line></svg>}
              </span>
            </div>
            <div class="flex items-center justify-between rounded-lg bg-white/[0.03] px-3 py-2">
              <span class="text-sm text-white/60">{competitorName}</span>
              <span>
                {feature.competitor === 'yes' && <svg class="inline-block text-green-500" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>}
                {feature.competitor === 'no' && <svg class="inline-block text-red-500" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>}
                {feature.competitor === 'partial' && <svg class="inline-block text-amber-500" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"></line></svg>}
              </span>
            </div>
          </div>
        </div>
      ))}
    </div>
  </div>
</section>
```

- [ ] **Step 3: Verify build**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Build succeeds. Existing pages using this component (bolt, lovable, etc.) still render correctly.

- [ ] **Step 4: Commit**

```bash
git add apps/marketing/src/components/blocks/comparison/ComparisonFeatureTable.astro
git commit -m "refactor(marketing): migrate ComparisonFeatureTable to Tailwind"
```

---

### Task 7: Migrate ComparisonPricing.astro to Tailwind

**Files:**
- Modify: `apps/marketing/src/components/blocks/comparison/ComparisonPricing.astro`

- [ ] **Step 1: Read the current file**

Read `apps/marketing/src/components/blocks/comparison/ComparisonPricing.astro` to get the exact current content.

- [ ] **Step 2: Rewrite with Tailwind classes**

Replace the entire file with:

```astro
---
// ComparisonPricing
// -----------------
// Shared pricing comparison section for /vs/ pages.
// Tailwind utility classes only.

type Props = {
  competitorName: string
  competitorCost: string
  competitorModel: string
  competitorFeatures: string[]
  frontmanCost?: string
  frontmanModel?: string
  frontmanFeatures?: string[]
}

const {
  competitorName,
  competitorCost,
  competitorModel,
  competitorFeatures,
  frontmanCost = 'Free',
  frontmanModel = 'Open source, BYOK',
  frontmanFeatures = [
    'Unlimited usage, no caps or credits',
    'Bring your own API keys (Claude, ChatGPT, OpenRouter)',
    'Or sign in with Claude/ChatGPT subscription via OAuth',
    'Apache 2.0 (client) / AGPL-3.0 (server)',
    'You pay your LLM provider directly',
  ],
} = Astro.props
---

<section class="flex justify-center bg-zinc-50 px-6 py-16 text-zinc-950 max-md:px-5 max-md:py-10">
  <div class="w-full max-w-[720px]">
    <h2 class="mb-8 text-[32px] font-bold tracking-tight text-zinc-950 max-md:text-2xl">Pricing Comparison</h2>
    <div class="grid grid-cols-2 gap-6 max-md:grid-cols-1">
      <!-- Frontman -->
      <div class="rounded-2xl border border-primary-500 bg-gradient-to-br from-primary-500/5 to-primary-500/[0.02] p-8 shadow-[0_0_0_1px_rgba(162,89,255,0.2)]">
        <h3 class="mb-2 text-xl font-bold text-zinc-950">Frontman</h3>
        <div class="mb-1 text-4xl font-extrabold tracking-tight text-primary-500">{frontmanCost}</div>
        <p class="mb-6 text-sm text-zinc-500">{frontmanModel}</p>
        <ul class="m-0 list-none p-0">
          {frontmanFeatures.map((f) => (
            <li class="relative py-1.5 pl-5 text-[15px] text-zinc-600 before:absolute before:left-0 before:text-zinc-400 before:content-['→']">{f}</li>
          ))}
        </ul>
      </div>
      <!-- Competitor -->
      <div class="rounded-2xl border border-zinc-200 bg-white p-8">
        <h3 class="mb-2 text-xl font-bold text-zinc-950">{competitorName}</h3>
        <div class="mb-1 text-4xl font-extrabold tracking-tight text-zinc-950">{competitorCost}</div>
        <p class="mb-6 text-sm text-zinc-500">{competitorModel}</p>
        <ul class="m-0 list-none p-0">
          {competitorFeatures.map((f) => (
            <li class="relative py-1.5 pl-5 text-[15px] text-zinc-600 before:absolute before:left-0 before:text-zinc-400 before:content-['→']">{f}</li>
          ))}
        </ul>
      </div>
    </div>
  </div>
</section>
```

- [ ] **Step 3: Verify build**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add apps/marketing/src/components/blocks/comparison/ComparisonPricing.astro
git commit -m "refactor(marketing): migrate ComparisonPricing to Tailwind"
```

---

### Task 8: Migrate ComparisonCTA.astro to Tailwind

**Files:**
- Modify: `apps/marketing/src/components/blocks/comparison/ComparisonCTA.astro`

- [ ] **Step 1: Read the current file**

Read `apps/marketing/src/components/blocks/comparison/ComparisonCTA.astro` to get the exact current content.

- [ ] **Step 2: Rewrite with Tailwind classes**

Replace the entire file with:

```astro
---
// ComparisonCTA
// -------------
// Shared bottom CTA section for /vs/ comparison pages.
// Tailwind utility classes only.

import Button from '../../ui/Button.astro'
---

<section class="flex justify-center border-t border-zinc-800 bg-zinc-950 px-6 py-20 max-md:px-5 max-md:py-12">
  <div class="w-full max-w-[720px]">
    <h2 class="mb-2 text-4xl font-bold tracking-tight text-zinc-50 max-md:text-[28px]">Try Frontman</h2>
    <p class="mb-8 text-[17px] text-zinc-500">One command. No account. No credit card. No prompt limits.</p>
    <div class="mb-8 flex flex-col gap-3">
      <div class="flex items-center justify-between rounded-lg border border-white/[0.08] bg-white/[0.04] px-4 py-3 max-md:flex-col max-md:items-start max-md:gap-1">
        <code class="font-mono text-sm text-zinc-50"><span class="mr-2 text-primary-500">$</span> npx @frontman-ai/nextjs install</code>
        <span class="text-[13px] text-zinc-500">Next.js</span>
      </div>
      <div class="flex items-center justify-between rounded-lg border border-white/[0.08] bg-white/[0.04] px-4 py-3 max-md:flex-col max-md:items-start max-md:gap-1">
        <code class="font-mono text-sm text-zinc-50"><span class="mr-2 text-primary-500">$</span> npx @frontman-ai/vite install</code>
        <span class="text-[13px] text-zinc-500">Vite (React, Vue, Svelte, SolidJS)</span>
      </div>
      <div class="flex items-center justify-between rounded-lg border border-white/[0.08] bg-white/[0.04] px-4 py-3 max-md:flex-col max-md:items-start max-md:gap-1">
        <code class="font-mono text-sm text-zinc-50"><span class="mr-2 text-primary-500">$</span> astro add @frontman-ai/astro</code>
        <span class="text-[13px] text-zinc-500">Astro</span>
      </div>
    </div>
    <div class="flex items-center gap-6 max-md:flex-col max-md:items-start max-md:gap-3">
      <Button size="lg" style="primary" link="https://github.com/frontman-ai/frontman">Star on GitHub</Button>
      <a href="https://discord.gg/xk8uXJSvhC" target="_blank" rel="noopener noreferrer" class="text-[15px] text-zinc-500 transition-colors hover:text-zinc-50">Join Discord</a>
    </div>
  </div>
</section>
```

- [ ] **Step 3: Verify build**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add apps/marketing/src/components/blocks/comparison/ComparisonCTA.astro
git commit -m "refactor(marketing): migrate ComparisonCTA to Tailwind"
```

---

### Task 9: Create ComparisonLayout.astro

The shared layout that composes all comparison components. Each per-competitor page imports this and passes data + slots.

**Files:**
- Create: `apps/marketing/src/layouts/ComparisonLayout.astro`

- [ ] **Step 1: Create the layout**

```astro
---
// ComparisonLayout
// ----------------
// Shared layout for /vs/ comparison pages.
// Composes all comparison components and accepts named slots for per-page prose.

import Layout from './Layout.astro'
import ComparisonHero from '../components/blocks/comparison/ComparisonHero.astro'
import ComparisonArchitectureDiagram from '../components/blocks/comparison/ComparisonArchitectureDiagram.astro'
import ComparisonFeatureTable from '../components/blocks/comparison/ComparisonFeatureTable.astro'
import type { ComparisonFeature } from '../components/blocks/comparison/ComparisonFeatureTable.astro'
import ComparisonContentSection from '../components/blocks/comparison/ComparisonContentSection.astro'
import ComparisonPricing from '../components/blocks/comparison/ComparisonPricing.astro'
import ComparisonAlternatives from '../components/blocks/comparison/ComparisonAlternatives.astro'
import ComparisonFAQ from '../components/blocks/comparison/ComparisonFAQ.astro'
import ComparisonCTA from '../components/blocks/comparison/ComparisonCTA.astro'
import ComparisonStructuredData from '../components/blocks/comparison/ComparisonStructuredData.astro'
import ComparisonDisclosure from '../components/ui/ComparisonDisclosure.astro'

type Alternative = {
  name: string
  slug: string
  oneLiner: string
}

type CompetitorInfo = {
  name: string
  slug: string
  url: string
  category: string
  description: string
  pricing: {
    cost: string
    model: string
    features: string[]
  }
}

type SEOInfo = {
  title: string
  description: string
}

type FAQ = {
  question: string
  answer: string
}

export type { ComparisonFeature, Alternative, CompetitorInfo, SEOInfo, FAQ }

type Props = {
  seo: SEOInfo
  competitor: CompetitorInfo
  heroTitle: string
  heroSubtitle: string
  features: ComparisonFeature[]
  faqs: FAQ[]
  alternatives: Alternative[]
  showArchitectureDiagram?: boolean
}

const {
  seo,
  competitor,
  heroTitle,
  heroSubtitle,
  features,
  faqs,
  alternatives,
  showArchitectureDiagram = true,
} = Astro.props
---

<Layout title={seo.title} description={seo.description}>
  <ComparisonStructuredData
    competitor={{ name: competitor.name, url: competitor.url, category: competitor.category, description: competitor.description, pricing: { cost: competitor.pricing.cost, model: competitor.pricing.model } }}
    faqs={faqs}
    seo={seo}
  />

  <!-- Hero -->
  <ComparisonHero title={heroTitle} subtitle={heroSubtitle}>
    <slot name="hero-summary" />
    <ComparisonDisclosure competitor={competitor.name} />
  </ComparisonHero>

  <!-- Architecture Diagram -->
  {showArchitectureDiagram && (
    <ComparisonArchitectureDiagram competitorName={competitor.name}>
      <slot name="architecture-diagram" />
    </ComparisonArchitectureDiagram>
  )}

  <!-- Feature Comparison Table -->
  <ComparisonFeatureTable competitorName={competitor.name} features={features} />

  <!-- What [Competitor] Does Well -->
  <ComparisonContentSection title={`What ${competitor.name} Does Well`} variant="light">
    <slot name="competitor-strengths" />
  </ComparisonContentSection>

  <!-- Where Frontman Is Different -->
  <ComparisonContentSection title="Where Frontman Is Different">
    <slot name="frontman-differentiators" />
  </ComparisonContentSection>

  <!-- Who Should Use [Competitor] -->
  <ComparisonContentSection title={`Who Should Use ${competitor.name}`} variant="light">
    <slot name="who-should-use-competitor" />
  </ComparisonContentSection>

  <!-- Who Should Use Frontman -->
  <ComparisonContentSection title="Who Should Use Frontman">
    <slot name="who-should-use-frontman" />
  </ComparisonContentSection>

  <!-- Pricing -->
  <ComparisonPricing
    competitorName={competitor.name}
    competitorCost={competitor.pricing.cost}
    competitorModel={competitor.pricing.model}
    competitorFeatures={competitor.pricing.features}
  />

  <!-- Alternatives -->
  <ComparisonAlternatives competitorName={competitor.name} alternatives={alternatives} />

  <!-- FAQ -->
  <ComparisonFAQ faqs={faqs} />

  <!-- CTA -->
  <ComparisonCTA />
</Layout>
```

- [ ] **Step 2: Verify build**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/marketing/src/layouts/ComparisonLayout.astro
git commit -m "feat(marketing): add ComparisonLayout shared layout for /vs/ pages"
```

---

### Task 10: Refactor cursor.astro to use ComparisonLayout

Rewrite the cursor page to use the shared layout. All prose content is preserved — just moved into named slots.

**Files:**
- Modify: `apps/marketing/src/pages/vs/cursor.astro`

- [ ] **Step 1: Read the current file**

Read `apps/marketing/src/pages/vs/cursor.astro` to get the exact current content (features, FAQs, prose).

- [ ] **Step 2: Rewrite using ComparisonLayout**

Replace the entire file with the refactored version. Key changes:
- Import `ComparisonLayout` instead of `Layout` + individual components
- Move SEO, features, FAQs, competitor info, alternatives into structured data objects
- Move prose into named slots
- Add architecture diagram SVG
- Remove all inline `<style>` (Tailwind handles everything)
- Update title tag for better keyword targeting

```astro
---
// /vs/cursor — Frontman vs Cursor Comparison Page
// Targets: "frontman vs cursor", "cursor alternative open source", "cursor alternatives 2026"

import ComparisonLayout from '../../layouts/ComparisonLayout.astro'
import type { ComparisonFeature, Alternative, CompetitorInfo, SEOInfo, FAQ } from '../../layouts/ComparisonLayout.astro'

const seo: SEOInfo = {
  title: 'Frontman vs Cursor: Open-Source AI Coding Tool Comparison (2026)',
  description:
    'Compare Frontman and Cursor side by side. Frontman is a browser-based AI agent for designers, PMs, and engineers. Cursor is an AI-powered IDE. Features, pricing, and architecture compared.',
}

const competitor: CompetitorInfo = {
  name: 'Cursor',
  slug: 'cursor',
  url: 'https://cursor.com',
  category: 'DeveloperApplication',
  description: 'AI-powered code editor based on VS Code with autocomplete, agent mode, and multi-file refactoring.',
  pricing: {
    cost: '$0–$200/mo',
    model: 'Freemium, proprietary',
    features: [
      'Hobby: Free — limited agent + tab completions',
      'Pro: $20/mo — extended agent, unlimited tabs',
      'Pro+: $60/mo — 3x usage on all models',
      'Ultra: $200/mo — 20x usage, priority access',
      'Teams: $40/user/mo — shared usage, SSO',
      'API key mode available (full BYOK)',
    ],
  },
}

const features: ComparisonFeature[] = [
  { name: 'Designer/PM friendly', frontman: 'yes', competitor: 'no', frontmanNote: 'Click elements, describe changes — no IDE needed', competitorNote: 'Requires IDE proficiency' },
  { name: 'Works in the browser', frontman: 'yes', competitor: 'no', frontmanNote: 'Opens alongside your running app', competitorNote: 'VS Code fork — desktop IDE' },
  { name: 'Click-to-select elements', frontman: 'yes', competitor: 'no', frontmanNote: 'Visual component selection', competitorNote: 'Must describe or find in file tree' },
  { name: 'Sees live DOM & styles', frontman: 'yes', competitor: 'no', frontmanNote: 'Browser-side MCP server inspects the live page', competitorNote: 'File-only context by default' },
  { name: 'Sees computed CSS', frontman: 'yes', competitor: 'no', frontmanNote: 'Runtime values, not class names', competitorNote: 'Reads source files; can extend via MCP' },
  { name: 'Hot reload feedback loop', frontman: 'yes', competitor: 'partial', frontmanNote: 'Instant in browser', competitorNote: "Can trigger builds via agent, doesn't see browser result" },
  { name: 'Framework-aware', frontman: 'yes', competitor: 'partial', frontmanNote: 'Deep plugin integration with Next.js, Astro, Vite', competitorNote: 'MCP servers, .cursorrules, project context' },
  { name: 'File-based editing', frontman: 'yes', competitor: 'yes', frontmanNote: 'Edits source files — real code, not overrides', competitorNote: 'Full file system access' },
  { name: 'Autocomplete', frontman: 'no', competitor: 'yes', competitorNote: 'Tab completion, inline suggestions' },
  { name: 'Multi-file refactoring', frontman: 'partial', competitor: 'yes', frontmanNote: 'Can edit multiple files, but not its primary workflow', competitorNote: 'Cross-file edits, Composer, agent mode' },
  { name: 'Terminal integration', frontman: 'no', competitor: 'yes', competitorNote: 'Built-in terminal, agent mode, cloud agents' },
  { name: 'Backend coding', frontman: 'partial', competitor: 'yes', frontmanNote: 'Can read/write any project file, but frontend-focused', competitorNote: 'Any language, any framework' },
  { name: 'Open source', frontman: 'yes', competitor: 'no', frontmanNote: 'Apache 2.0 / AGPL-3.0', competitorNote: 'Proprietary' },
  { name: 'BYOK (bring your own key)', frontman: 'yes', competitor: 'yes', frontmanNote: 'OpenRouter, Anthropic, OpenAI', competitorNote: 'API key mode, bring your own models' },
  { name: 'Self-hostable', frontman: 'yes', competitor: 'no' },
]

const faqs: FAQ[] = [
  {
    question: 'Can our designers actually use Frontman without learning an IDE?',
    answer: 'Yes. Frontman runs in the browser alongside your running app — no VS Code, no terminal. Designers click elements they want to change, describe the update in plain English, and see results via hot reload. Every change produces a real source file edit that engineers can review as a normal pull request. The interface is the browser they already know.',
  },
  {
    question: 'Will this break our design system or create code engineers have to clean up?',
    answer: "No. Frontman edits the same source files your engineers write — real component code, not CSS overrides or a separate layer. Changes go through your existing code review process. Because Frontman integrates as a framework plugin (Next.js, Astro, or Vite), it understands your component structure and source maps. Engineers review and merge like any other PR.",
  },
  {
    question: 'Can Frontman replace Cursor for our engineering team?',
    answer: "For frontend visual editing — clicking elements, adjusting layout, fixing CSS — yes. For agentic coding workflows, autocomplete, terminal integration, or large codebase refactoring, no. They serve different roles on the team. Many teams use Cursor for backend and general-purpose engineering, and Frontman for cross-functional UI iteration where designers and PMs are involved.",
  },
  {
    question: 'Does Frontman work alongside Cursor?',
    answer: 'Yes. Engineers use Cursor as their IDE for backend and general coding. Designers and PMs use Frontman in the browser for visual changes. Both edit the same source files. Changes from either tool are reflected through normal file watching and hot reload.',
  },
  {
    question: "What does Frontman see that Cursor doesn't?",
    answer: "Frontman integrates with your framework as a plugin and runs a browser-side MCP server that inspects the live DOM tree, computed CSS styles (not just class names), viewport layout and spacing, and can take screenshots and emulate different devices. The framework plugin captures console logs, build errors, and resolves source locations via source maps. Cursor reads your source files and doesn't natively see what they render — though it can connect to browser tools via MCP servers, that requires additional setup.",
  },
  {
    question: 'How does pricing work for a team with designers, PMs, and engineers?',
    answer: "Frontman is free while in beta. We plan to introduce per-seat team pricing — details are coming soon. The client libraries are Apache 2.0 and the server is AGPL-3.0, so self-hosting will always be an option. You bring your own API keys to Anthropic, OpenAI, or OpenRouter, or sign in with your Claude or ChatGPT subscription via OAuth.",
  },
]

const alternatives: Alternative[] = [
  { name: 'Frontman', slug: '', oneLiner: 'Open-source AI agent in your browser. Designers and PMs click elements, describe changes, ship real code.' },
  { name: 'Claude Code', slug: 'claude-code', oneLiner: 'Terminal-based AI coding agent from Anthropic. Powerful for backend and full-stack work.' },
  { name: 'GitHub Copilot', slug: 'copilot', oneLiner: 'AI pair programmer in VS Code and JetBrains. Autocomplete-focused with chat and agent features.' },
  { name: 'Windsurf', slug: 'windsurf', oneLiner: 'AI-native IDE with Cascade agent for multi-step coding workflows.' },
  { name: 'Stagewise', slug: 'stagewise', oneLiner: 'Browser-based visual editing toolbar. Lightweight, frontend-focused.' },
]
---

<ComparisonLayout
  seo={seo}
  competitor={competitor}
  heroTitle="Frontman vs Cursor"
  heroSubtitle="Your Whole Team Can Ship UI Changes — Not Just Engineers"
  features={features}
  faqs={faqs}
  alternatives={alternatives}
>
  <!-- Hero Summary (GEO Lead — AI-citable first 150 words) -->
  <Fragment slot="hero-summary">
    <p>
      If you have a design system and a growing product team, you know the bottleneck: every spacing tweak, copy change, or component adjustment becomes a ticket for engineering. Designers spec it, PMs prioritize it, and developers implement it days later. The feedback loop is slow and expensive.
    </p>
    <p>
      <a href="https://frontman.sh" class="text-link">Frontman</a> is an open-source AI agent that lives in your browser, right alongside your running app. Designers and PMs click elements, describe changes in plain English, and Frontman edits the actual source files — producing real code diffs engineers can review. No IDE required. It integrates with your framework (Next.js, Astro, or Vite) as a plugin and uses a browser-side MCP server to see live DOM, computed styles, and rendered components.
    </p>
    <p>
      <a href="https://cursor.com" class="text-link" rel="nofollow">Cursor</a> is a commercial AI-powered IDE based on VS Code. It's excellent for engineers — tab completion, agentic coding, multi-file refactoring, terminal integration. But it requires IDE proficiency and doesn't natively see what your app renders in the browser.
    </p>
    <p class="summary-emphasis">
      The core difference: Cursor makes engineers faster in the IDE. Frontman lets your whole team — designers, PMs, and engineers — iterate on UI together in the browser. Many teams use both.
    </p>
  </Fragment>

  <!-- Architecture Diagram -->
  <Fragment slot="architecture-diagram">
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 320" class="w-full max-w-[800px]" role="img" aria-label="Architecture comparison: Frontman works in the browser with live DOM access while Cursor works in the IDE with file system access">
      <!-- Frontman side -->
      <text x="200" y="28" text-anchor="middle" fill="#A259FF" font-size="16" font-weight="700" font-family="ui-monospace, monospace">Frontman</text>
      <rect x="60" y="44" width="280" height="40" rx="8" fill="rgba(162,89,255,0.12)" stroke="#A259FF" stroke-width="1.5"/>
      <text x="200" y="69" text-anchor="middle" fill="#fafafa" font-size="13" font-family="system-ui">Team (Designers, PMs, Engineers)</text>
      <line x1="200" y1="84" x2="200" y2="104" stroke="#A259FF" stroke-width="1.5" stroke-dasharray="4"/>
      <text x="200" y="100" text-anchor="middle" fill="#71717a" font-size="10" font-family="system-ui">click &amp; describe</text>
      <rect x="60" y="108" width="280" height="40" rx="8" fill="rgba(162,89,255,0.08)" stroke="#A259FF" stroke-width="1.5"/>
      <text x="200" y="133" text-anchor="middle" fill="#A259FF" font-size="13" font-weight="600" font-family="system-ui">Browser (Live App)</text>
      <line x1="200" y1="148" x2="200" y2="168" stroke="#A259FF" stroke-width="1.5" stroke-dasharray="4"/>
      <text x="200" y="164" text-anchor="middle" fill="#71717a" font-size="10" font-family="system-ui">MCP server</text>
      <rect x="60" y="172" width="280" height="40" rx="8" fill="rgba(162,89,255,0.08)" stroke="#A259FF" stroke-width="1.5"/>
      <text x="200" y="197" text-anchor="middle" fill="#A259FF" font-size="13" font-weight="600" font-family="system-ui">Live DOM + Computed Styles</text>
      <line x1="200" y1="212" x2="200" y2="232" stroke="#A259FF" stroke-width="1.5" stroke-dasharray="4"/>
      <text x="200" y="228" text-anchor="middle" fill="#71717a" font-size="10" font-family="system-ui">source maps</text>
      <rect x="60" y="236" width="280" height="40" rx="8" fill="rgba(162,89,255,0.06)" stroke="#A259FF" stroke-width="1"/>
      <text x="200" y="261" text-anchor="middle" fill="#a1a1aa" font-size="13" font-family="system-ui">Source Files (real code edits)</text>

      <!-- Divider -->
      <line x1="400" y1="20" x2="400" y2="300" stroke="#27272a" stroke-width="1" stroke-dasharray="6"/>

      <!-- Cursor side -->
      <text x="600" y="28" text-anchor="middle" fill="#71717a" font-size="16" font-weight="700" font-family="ui-monospace, monospace">Cursor</text>
      <rect x="460" y="44" width="280" height="40" rx="8" fill="rgba(255,255,255,0.06)" stroke="#3f3f46" stroke-width="1.5"/>
      <text x="600" y="69" text-anchor="middle" fill="#fafafa" font-size="13" font-family="system-ui">Developer</text>
      <line x1="600" y1="84" x2="600" y2="104" stroke="#3f3f46" stroke-width="1.5" stroke-dasharray="4"/>
      <text x="600" y="100" text-anchor="middle" fill="#71717a" font-size="10" font-family="system-ui">type &amp; prompt</text>
      <rect x="460" y="108" width="280" height="40" rx="8" fill="rgba(255,255,255,0.04)" stroke="#3f3f46" stroke-width="1.5"/>
      <text x="600" y="133" text-anchor="middle" fill="#a1a1aa" font-size="13" font-weight="600" font-family="system-ui">VS Code IDE</text>
      <line x1="600" y1="148" x2="600" y2="168" stroke="#3f3f46" stroke-width="1.5" stroke-dasharray="4"/>
      <text x="600" y="164" text-anchor="middle" fill="#71717a" font-size="10" font-family="system-ui">file access</text>
      <rect x="460" y="172" width="280" height="40" rx="8" fill="rgba(255,255,255,0.04)" stroke="#3f3f46" stroke-width="1.5"/>
      <text x="600" y="197" text-anchor="middle" fill="#a1a1aa" font-size="13" font-weight="600" font-family="system-ui">File System + AST</text>
      <line x1="600" y1="212" x2="600" y2="232" stroke="#3f3f46" stroke-width="1.5" stroke-dasharray="4"/>
      <text x="600" y="228" text-anchor="middle" fill="#71717a" font-size="10" font-family="system-ui">direct edits</text>
      <rect x="460" y="236" width="280" height="40" rx="8" fill="rgba(255,255,255,0.03)" stroke="#3f3f46" stroke-width="1"/>
      <text x="600" y="261" text-anchor="middle" fill="#a1a1aa" font-size="13" font-family="system-ui">Source Files (real code edits)</text>

      <!-- Highlight callout -->
      <rect x="62" y="288" width="276" height="24" rx="4" fill="rgba(162,89,255,0.15)"/>
      <text x="200" y="304" text-anchor="middle" fill="#A259FF" font-size="11" font-weight="600" font-family="system-ui">Sees what users see</text>
      <rect x="462" y="288" width="276" height="24" rx="4" fill="rgba(255,255,255,0.04)"/>
      <text x="600" y="304" text-anchor="middle" fill="#71717a" font-size="11" font-weight="600" font-family="system-ui">Sees what developers write</text>
    </svg>
  </Fragment>

  <!-- What Cursor Does Well -->
  <Fragment slot="competitor-strengths">
    <p>Cursor makes developers faster if you already live in an IDE. It's popular for good reason.</p>
    <p><strong>Autocomplete is best-in-class.</strong> Tab completion understands your codebase, predicts multi-line edits, and learns from your patterns. For raw typing speed, nothing in this comparison comes close.</p>
    <p><strong>Agent mode is powerful.</strong> Cursor's agent can plan multi-step changes, run terminal commands, interpret output, and iterate on errors — all within the IDE. Cloud agents and background agents let work continue asynchronously. Frontman's AI agent is focused on browser-visible changes, not general-purpose coding workflows.</p>
    <p><strong>Multi-file refactoring works.</strong> Cursor's Composer and agent mode can rename a prop across 15 files, update imports, and fix type errors in one pass. Frontman can edit multiple files, but it's not its primary workflow.</p>
    <p><strong>Backend and general-purpose coding.</strong> Cursor handles Python, Go, Rust, SQL, infrastructure-as-code — any language, any project. Frontman is frontend-focused. It can read and write any project file, but its strengths are in visual editing where browser context matters.</p>
    <p><strong>Terminal integration.</strong> Cursor's terminal agent can run commands, read output, and fix errors automatically. Frontman has no terminal — it captures console logs and build errors from the dev server, but cannot run arbitrary commands.</p>
    <p>Cursor supports MCP servers, allowing it to connect to external tools, databases, APIs, and even browser automation. Combined with .cursorrules for project-specific context, this makes Cursor highly customizable.</p>
    <p>Cursor has millions of users, extensive documentation, and a mature extension ecosystem inherited from VS Code.</p>
  </Fragment>

  <!-- Where Frontman Is Different -->
  <Fragment slot="frontman-differentiators">
    <p><strong>Your whole team can touch the UI.</strong> Designers click the element that needs work, describe the change in plain English, and Frontman edits the actual source files. PMs can adjust copy, spacing, or component props without filing a ticket. Engineers review the diff like any other PR. Everyone works from the same running app — no Figma-to-code translation step, no "can you move this 4px to the left" Slack threads.</p>
    <p><strong>It sees what the browser sees.</strong> Cursor reads your JSX files, but by default it has never seen what they render. It doesn't know that your hero section overflows at 768px, that the computed font size is 18px not 16px, or that a sibling component's margin is pushing your layout. Frontman integrates with your framework as a plugin and runs a browser-side MCP server that inspects live DOM, computed CSS, viewport layout, and rendered component hierarchy. When you click an element, Frontman resolves the source location via source maps and knows exactly which file, component, and line rendered it.</p>
    <p><strong>Click-to-edit workflow.</strong> Instead of describing which file to open, you click the element you want to change. The AI already knows the component, its source location, its styles, and its context in the rendered page. "Make this card's shadow more subtle" works because Frontman can see the card.</p>
    <p><strong>Hot reload closes the feedback loop.</strong> Frontman edits actual source files, and the framework's built-in HMR handles live reloading automatically. Edit &rarr; see result &rarr; edit again happens in the browser without switching windows. A designer can iterate through three variations in the time it takes to write one Jira ticket.</p>
    <p><strong>Real code, not overrides.</strong> Every change Frontman makes is a source file edit — the same code your engineers write by hand. No visual-editor CSS overrides, no separate layer to maintain. Changes go through your existing review process and ship like any other commit. Your design system stays clean.</p>
    <p><strong>Open source and BYOK.</strong> Frontman is free while in beta, with per-seat team pricing coming soon. The client libraries are Apache 2.0 and the server is AGPL-3.0 — self-hosting will always be an option. You bring your own API keys to Anthropic, OpenAI, or OpenRouter — or sign in with your Claude or ChatGPT subscription via OAuth.</p>
  </Fragment>

  <!-- Who Should Use Cursor -->
  <Fragment slot="who-should-use-competitor">
    <p>Cursor is the better choice for engineers who want AI in their IDE. Specifically:</p>
    <ul>
      <li><strong>Backend developers</strong> working in Python, Go, Rust, or any non-frontend language</li>
      <li><strong>Large codebase refactoring</strong> — renaming across dozens of files, updating APIs, migrating patterns</li>
      <li><strong>Agentic coding workflows</strong> — if you want the AI to plan, execute, and iterate across files and terminal</li>
      <li><strong>Autocomplete-dependent workflows</strong> — if inline suggestions are core to how you code</li>
      <li><strong>Full-stack work</strong> where you move between frontend and backend in the same session</li>
      <li><strong>Teams standardized on VS Code</strong> — Cursor inherits the entire VS Code extension ecosystem</li>
    </ul>
  </Fragment>

  <!-- Who Should Use Frontman -->
  <Fragment slot="who-should-use-frontman">
    <p>Frontman is built for product teams where UI iteration is a bottleneck — not just individual developers. Specifically:</p>
    <ul>
      <li><strong>Design system teams at growing startups</strong> — your system is live, your components are real, and you need designers and engineers iterating on them together without a Figma&rarr;ticket&rarr;PR bottleneck</li>
      <li><strong>Designers who want to iterate directly on the product</strong> — click elements in the running app, describe changes, and see results instantly. No IDE, no terminal, no waiting for engineering capacity</li>
      <li><strong>PMs who ship small UI changes themselves</strong> — update copy, adjust spacing, tweak component props. Every change is a real code diff your engineers can review</li>
      <li><strong>Engineering leads reducing design-to-code handoff friction</strong> — fewer "make it match the Figma" tickets, more direct iteration on the actual product</li>
      <li><strong>Teams using Next.js, Astro, or Vite</strong> — deep framework plugin integration means Frontman understands your component structure, not just file contents</li>
      <li><strong>Companies with security or compliance requirements</strong> — open source (Apache 2.0 / AGPL-3.0), self-hostable, BYOK. Free during beta with team pricing coming soon</li>
    </ul>
    <p>Many teams use both tools. Engineers use Cursor for backend work, refactoring, and general-purpose coding. The broader product team uses Frontman for visual iteration in the browser.</p>
    <p>For a deeper technical comparison including Claude Code, read our <a href="/blog/frontman-vs-cursor-vs-claude-code/" class="text-link">full comparison of Frontman, Cursor, and Claude Code</a>. Also see: <a href="/vs/stagewise/" class="text-link">Frontman vs Stagewise</a> for a comparison with another browser-based tool.</p>
  </Fragment>
</ComparisonLayout>
```

- [ ] **Step 3: Verify build**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Build succeeds. The cursor page now renders using the shared layout.

- [ ] **Step 4: Visual check — verify page renders all sections**

Run: `cd apps/marketing && yarn dev &` then open `http://localhost:4321/vs/cursor/` in a browser.

Verify:
- Hero section with title, subtitle, summary prose, and disclosure
- Architecture diagram SVG (two-column Frontman vs Cursor flow)
- Feature comparison table (15 features, desktop table + mobile cards)
- "What Cursor Does Well" section (light background)
- "Where Frontman Is Different" section (dark background)
- "Who Should Use Cursor" section (light background)
- "Who Should Use Frontman" section (dark background)
- Pricing comparison (two cards)
- "Cursor Alternatives" section (grid of cards)
- FAQ accordion (6 questions)
- CTA with install commands

- [ ] **Step 5: Verify structured data**

View page source, search for `application/ld+json`. Verify 4 JSON-LD blocks:
1. FAQPage with 6 questions
2. SoftwareApplication for Frontman with `isSimilarTo` pointing to Cursor
3. SoftwareApplication for Cursor
4. WebPage with `reviewedBy` Organization

Plus the existing Organization and BreadcrumbList from `StructuredData.astro`.

- [ ] **Step 6: Verify no regression on other pages**

Run: `cd apps/marketing && yarn build 2>&1 | tail -20`
Expected: Full build succeeds — bolt.astro and other pages using the shared components still build correctly.

- [ ] **Step 7: Commit**

```bash
git add apps/marketing/src/pages/vs/cursor.astro
git commit -m "refactor(marketing): rewrite cursor comparison page with ComparisonLayout

Migrates /vs/cursor/ from 790-line inline page to shared
ComparisonLayout with named slots. Adds architecture diagram SVG,
alternatives section, and Product structured data.

Closes #792"
```

---

### Task 11: Verify and fix any visual regressions

Final pass to catch any Tailwind differences from the original scoped styles.

**Files:**
- May modify any component from Tasks 1-10

- [ ] **Step 1: Build the full marketing site**

Run: `cd apps/marketing && yarn build 2>&1 | tail -30`
Expected: Build succeeds with no warnings.

- [ ] **Step 2: Compare rendered output**

Start the dev server and check these pages still render correctly:
- `/vs/cursor/` — the refactored page
- `/vs/bolt/` — uses ComparisonFeatureTable, ComparisonPricing, ComparisonCTA (all migrated to Tailwind)
- `/vs/lovable/` — same shared components
- `/vs/` — index page (no changes expected)
- `/compare/` — hub page (no changes expected)

- [ ] **Step 3: Fix any issues found**

If spacing, colors, or layout differ from the original, adjust the Tailwind classes in the affected component. Common issues:
- `max-w-[720px]` vs `max-w-[900px]` — match the original component's width
- Missing responsive breakpoints — check `max-md:` prefixes
- Color differences — use exact zinc scale values from the originals

- [ ] **Step 4: Final commit (if fixes needed)**

```bash
git add -A
git commit -m "fix(marketing): visual regression fixes for comparison components"
```
