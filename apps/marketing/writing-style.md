# Frontman Blog Writing Style

This guide documents how blog posts in `src/content/blog/` are structured, optimized for search, and written. It reflects patterns across the current blog, not generic content-marketing advice.

## Editorial Model

Each post should own one search intent and one editorial role. Do not make several posts repeat the same problem narrative, product explanation, and workflow.

Primary roles:

- **Problem diagnosis:** Define a problem, demonstrate it with concrete scenarios, name the underlying concept, and link to the solution.
- **Product announcement:** Reference the problem briefly, explain capabilities and workflow changes, disclose tradeoffs, and end with setup instructions.
- **Tutorial:** Promise one outcome, list prerequisites, walk through exact steps, show the resulting diff, and explain what happened.
- **Comparison or buyer guide:** Give the recommendation first, compare tools by workflow, disclose bias, and state when to choose or skip each option.
- **Technical explainer:** Define a concept precisely, cite primary sources, explain mechanics, and distinguish what it does from what it does not do.
- **Operational audit:** Organize each issue as what breaks, how to fix it, and how to roll back. End with a usable checklist.

Related posts should form an intent path instead of duplicating content:

```text
Problem diagnosis
-> product explanation
-> technical deep dive
-> tutorial
-> comparison
-> conversion page
```

## Frontmatter

Every post requires:

```yaml
---
title: 'Readable Human Title'
description: 'Direct summary of the answer and scope.'
pubDate: 2026-07-15T00:00:00Z
image: '/blog/post-slug-cover.png'
author: 'Danni Friedland'
tags: ['primary-topic', 'secondary-topic']
---
```

Use optional fields when applicable:

```yaml
seoTitle: 'Exact Search Query or Keyword Title'
updatedDate: 2026-07-15T00:00:00Z
authorRole: 'Co-founder, Frontman'
imageWidth: 1200
imageHeight: 450
imageAlt: 'Specific description of this post cover'
faq:
  - question: 'Exact user question?'
    answer: 'Self-contained direct answer.'
comparisonItems:
  - name: 'Tool name'
    url: 'https://example.com'
    description: 'What distinguishes this tool.'
softwareApplication:
video:
```

Field behavior:

- `title` becomes visible H1 and `BlogPosting.headline`.
- `seoTitle`, when present, becomes document and social title. Layout appends `| Frontman`.
- `description` becomes meta description, Open Graph description, Twitter description, RSS description, and schema description. Metadata rendering truncates it to 160 characters.
- `updatedDate` appears visibly, populates article metadata, and controls sitemap freshness.
- `tags` become tag links, article tags, schema keywords, and first-tag `articleSection`.
- `faq`, `comparisonItems`, `softwareApplication`, and `video` activate corresponding structured data.

## Post Structure

### Opening

Start with one of these:

- A recognizable failure scenario
- A direct recommendation
- A sharp contradiction
- A concrete promised outcome
- A specific recent event

Name products, files, classes, workflows, or affected users immediately. Avoid broad category introductions.

Good pattern:

> Name any AI coding agent. Claude Code. Cursor. GitHub Copilot. Windsurf.

Then state the thesis quickly:

> For frontend work, it is not even close.

For search-led posts, answer the query within the first one to three paragraphs. Use one explicit summary format where useful:

```markdown
**Quick answer:** Complete answer in one to three sentences.
```

or:

```markdown
> **TL;DR:** Complete answer in one compact paragraph.
```

### Body

Use H2 headings for primary sections. Page layout already renders H1, so do not jump directly from H1 to H3. Use H3 only inside an H2 section.

Organize body around decisions and evidence, not a generic introduction/body/conclusion sequence.

Preferred section types:

- What breaks
- How to fix it
- How to roll back
- How it works
- Who should use what
- What changes in practice
- Honest tradeoffs
- When not to use this
- How to choose
- What happened under the hood

Support claims with at least one concrete artifact:

- Exact command
- Code snippet
- Before/after diff
- Comparison table
- Named product
- Numerical result
- Primary-source link
- Reproducible scenario
- Explicit limitation

### Ending

Do not merely restate the article. End with an action:

- Install Frontman
- Run one specific tutorial
- Read a directly related technical post
- Compare against a named alternative
- Test on staging
- Review the security or architecture model

Keep CTA specific. Link to one or two logical next steps instead of dumping a generic related-post list.

## Role-Specific Structures

### Problem Diagnosis

Example: `introducing-frontman.md`

1. Name familiar tools or situation.
2. State contradiction.
3. Give quick answer.
4. Demonstrate problem through concrete scenarios.
5. Name underlying concept.
6. Explain why obvious solutions fail.
7. Add restrained product bridge at end.

Keep product pitch out of main diagnosis. Let post establish category language and link to launch or tutorial content.

### Product Announcement

Example: `frontman-launch.md`

1. Reference problem in one sentence and link to diagnosis post.
2. Explain product behavior with examples.
3. Describe target team and differentiator.
4. Explain workflow change.
5. Include honest tradeoffs.
6. Explain security or open-source rationale.
7. End with installation CTA and sibling links.

Product announcements must say what does not work. Do not present narrow visual-editing capabilities as general software-engineering automation.

### Tutorial

Examples: `getting-started.md`, `tutorial-nextjs-runtime-context.md`

1. Promise one outcome and time estimate.
2. List prerequisites.
3. Number each step.
4. Include executable commands.
5. Show realistic source before and after.
6. Explain what happened under hood.
7. State when not to use technique.
8. End with docs and related guide.

Keep scope narrow. One complete button-color edit is stronger than a tour of every feature.

### Comparison or Buyer Guide

Examples: `frontman-vs-cursor-vs-claude-code.md`, `best-open-source-ai-coding-tools-2026.md`

1. Answer recommendation immediately.
2. Declare author bias or product involvement.
3. Provide quick-answer table.
4. Compare by workflow or architecture, not feature count alone.
5. Give each option a use-when and skip-when rule.
6. Cover pricing, license, maintenance status, adoption, and limitations when relevant.
7. Finish with decision rules.

When Frontman appears, disclose that we built it. State where competitors are stronger. Include Frontman's current limitations, such as maturity, framework coverage, community size, or source-mapping constraints.

### Technical Explainer

Examples: `what-is-webmcp.md`, `runtime-context-gap.md`, `ai-code-review-hallucination.md`

1. Open with failure scenario or contrarian claim.
2. Define term precisely.
3. Link primary sources.
4. Show mechanics with code, diagrams, traces, or examples.
5. Separate capabilities from non-capabilities.
6. Give operational guidance.
7. State research date when facts are volatile.

## SEO Rules

### Match Exact Search Intent

Use visible title for readability and `seoTitle` for exact query matching when those needs differ.

Examples of established query forms:

- `Cline AI Coding Tool Review 2026`
- `Edit a Website Without a Developer`
- `AI Tools for UI/UX Designers 2026`
- `Roo Code vs Cline 2026`
- `WordPress AI Plugins 2026`

Prefer category, comparison, year, use case, or outcome over abstract thought-leadership titles.

### Answer Early

Definition, comparison, and buyer-intent posts should provide a self-contained answer before background. Searcher should understand recommendation from opening or quick-answer table.

### Build Internal-Link Clusters

Use contextual anchor text inside relevant paragraphs. Core hubs include:

- Runtime context gap
- Browser-aware AI tools
- Frontend agents
- Security model
- Getting started
- Tool comparisons
- Design-system collaboration

Do not repeat a sibling post's full explanation. Summarize in one sentence and link to canonical deep dive.

### Demonstrate Freshness

For volatile comparisons and release coverage:

- Add `updatedDate` when facts change.
- Include visible status-check date.
- State when counts are approximate.
- Link primary sources.
- Update maintenance status, pricing, license, framework support, and release information.

### Use Structured Data Intentionally

Add FAQ frontmatter only when post answers real recurring queries. Answers must stand alone without requiring surrounding article context.

Use `comparisonItems` for actual ranked or compared entities. Use `softwareApplication` when post defines or profiles software. Use `video` when page contains corresponding video content.

### Images

Current cover generator outputs `1200x450`. Declare matching dimensions:

```yaml
imageWidth: 1200
imageHeight: 450
```

Always provide post-specific `imageAlt`. Do not rely on generic Frontman fallback.

## Writing Style

### Voice

Write directly, technically, skeptically, and with clear judgment.

Use:

- Short opening sentences
- Sentence fragments for emphasis
- Second person for workflows
- First person for disclosure or direct experience
- Explicit recommendations
- Concrete nouns and verbs
- Contrast between source and runtime, code and pixels, demo and production

Typical rhythm:

> The shape was right. The work was missing.

Common construction:

> This is not a prompt engineering problem. It is an architecture problem.

Avoid filler such as:

- In today's rapidly evolving landscape
- AI is transforming everything
- Improve productivity
- Seamless and powerful
- Revolutionary solution
- It is important to note

Replace abstractions with observable details: tab switches, file paths, CSS classes, review steps, dates, star counts, licenses, request volume, or code diffs.

### Paragraphs

Keep most paragraphs to one to three sentences. Break dense material with:

- Descriptive headings
- Bold lead-ins
- Tables
- Bullets
- Code blocks
- Blockquoted prompts
- ASCII diagrams

Do not force every post to same length. Match depth to intent:

- Announcements and focused tutorials: roughly 500-1,000 words
- Explainers: roughly 1,000-2,000 words
- Comparisons and research audits: roughly 2,500-4,500 words

### Claims and Credibility

Be opinionated, but make opinion inspectable.

Good:

> Cline is the safest default for an open-source VS Code AI coding agent in 2026.

Then explain why and name cases where it is wrong choice.

Use primary sources for standards, release changes, API behavior, benchmarks, licenses, and project status. State uncertainty explicitly. Do not hide weak evidence behind confident prose.

### Product Positioning

Frame Frontman through architectural thesis rather than feature list:

> AI coding agents lack browser runtime context.

Explain problem first. Introduce Frontman after reader understands why runtime context matters. Product mention should connect directly to article's subject, not appear as unrelated sales paragraph.

## Known Inconsistencies to Avoid

### Skipped Heading Levels

Some older posts use H3 immediately after page H1. New posts should use H2 for primary sections and H3 only as child sections.

### Incorrect Social Image Dimensions

SEO component defaults to `1200x630`, while generated covers are `1200x450`. Always set explicit `imageWidth` and `imageHeight` until generator or default changes.

### Generic Image Alt Text

Posts without `imageAlt` receive brand-level fallback unrelated to post topic. Always write specific alt text.

### Repeated Product Narrative

Do not repeat full "click element, describe change, get PR" workflow in every post. Assign canonical explanation to product or tutorial post, summarize briefly elsewhere, and link.

## Recommended Template

```markdown
---
title: 'Readable Human Title'
seoTitle: 'Exact Search Query or Keyword Title'
pubDate: 2026-07-15T00:00:00Z
updatedDate: 2026-07-15T00:00:00Z
description: 'Direct answer and concrete scope, written for search snippets.'
author: 'Danni Friedland'
authorRole: 'Co-founder, Frontman'
image: '/blog/post-slug-cover.png'
imageWidth: 1200
imageHeight: 450
imageAlt: 'Specific description of this post cover'
tags: ['primary-topic', 'secondary-topic']
faq:
  - question: 'Exact user question?'
    answer: 'Self-contained direct answer.'
---

Open with recognizable failure, decision, or outcome.

**Quick answer:** Give complete answer in one to three sentences.

## Primary Decision or Definition

Explain core concept using concrete examples.

## Evidence or Workflow

Use code, commands, data, tables, or named products.

## Tradeoffs or Limitations

State what fails, who should not use approach, and uncertainty.

## How to Apply It

Give operational steps or decision rules.

## Next Step

One specific CTA plus one or two contextually related internal links.
```

Core rule: one post, one search intent, one distinct role. Answer early, prove claims concretely, disclose bias, include limitations, and route readers to sibling content instead of repeating it.
