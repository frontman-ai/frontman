---
title: 'Add Runtime Context to AI Coding in Next.js'
pubDate: 2026-02-23T07:00:00Z
description: 'Build a reproducible mobile-overflow bug in a Next.js page, select it in Frontman, apply a scoped CSS Module fix, and verify the result.'
author: 'Danni Friedland'
articleSection: 'Tutorial'
image: '/blog/tutorial-nextjs-runtime-context-cover.png'
imageAlt: 'Next.js runtime context tutorial cover'
tags: ['tutorial', 'getting-started', 'ai']
updatedDate: 2026-07-30T00:00:00Z
---

This tutorial starts after installation. You will create a deliberate mobile overflow bug, point Frontman at the rendered element, request a constrained fix, and verify the result in the browser and source diff. For installation details, use the [Next.js integration guide](/docs/integrations/nextjs/).

The example uses a CSS Module, an officially supported Next.js styling method. See the [Next.js CSS documentation](https://nextjs.org/docs/app/getting-started/css#css-modules).

## Prerequisites

- A Next.js 15.5 or later project using the App Router
- Frontman installed with `npx @frontman-ai/nextjs install`
- Your development server running
- An AI provider connected in Frontman
- A root layout that imports `app/globals.css`

Open `http://localhost:3000/frontman` and confirm that your application loads in the preview before continuing.

## 1. Create a page with a known bug

First, make the viewport assumptions explicit. Ensure `app/globals.css`, imported by your root layout, contains:

```css
html,
body {
	margin: 0;
	padding: 0;
}
```

These rules remove browser body spacing. The route styles below explicitly set box sizing, so an existing project-wide `border-box` reset cannot prevent the reproduction.

Create `app/runtime-context/page.tsx`:

```tsx
import styles from './page.module.css'

export default function RuntimeContextPage() {
	return (
		<main className={styles.page}>
			<section className={styles.panel}>
				<p className={styles.eyebrow}>Runtime context exercise</p>
				<h1>Ship the page, not the guess</h1>
				<p>
					This panel is intentionally wider than a mobile viewport. Select it in Frontman and ask
					for a scoped fix.
				</p>
				<button type="button">Review change</button>
			</section>
		</main>
	)
}
```

Create `app/runtime-context/page.module.css`:

```css
.page {
	box-sizing: border-box;
	width: 100%;
	min-height: 100vh;
	padding: 24px;
	background: #f2f0e8;
}

.panel {
	box-sizing: content-box;
	width: 520px;
	padding: 32px;
	border: 1px solid #222;
	background: #fff;
}

.eyebrow {
	font-size: 0.75rem;
	font-weight: 700;
	letter-spacing: 0.08em;
	text-transform: uppercase;
}
```

Visit `http://localhost:3000/runtime-context`. At a 390-pixel viewport, the border-box page has 342 pixels of content width after 24-pixel padding on each side. The panel explicitly declares a 520-pixel content-box width, and its padding and border make the rendered box wider still. Horizontal overflow is therefore expected regardless of starter-template reset styles.

## 2. Capture runtime context

In Frontman:

1. Navigate the preview to `/runtime-context`.
2. Switch to a mobile viewport, such as 390 pixels wide.
3. Select the overflowing white panel as an annotation.
4. Send this prompt:

> Fix horizontal overflow for the selected panel at a 390px viewport. Keep 24px page padding, keep the current markup, and edit only `app/runtime-context/page.module.css`. Explain the CSS sizing cause, then show the diff. Do not change typography or colors.

The annotation gives the task a concrete rendered target. Depending on framework and source-map availability, Frontman can attach a selector, screenshot, component metadata, and source location. The agent can also use browser tools for the DOM and screenshot, then use dev-server tools to read and edit the project file. See [How the Agent Works](/docs/using/how-the-agent-works/) for the verified tool flow.

## 3. Review the fix

One minimal valid result is:

```css
.panel {
	box-sizing: border-box;
	width: 100%;
	max-width: 520px;
	padding: 32px;
	border: 1px solid #222;
	background: #fff;
}
```

Why it works:

- `width: 100%` lets the panel use available content width instead of forcing 520 pixels.
- `max-width: 520px` preserves the intended desktop limit.
- `box-sizing: border-box` includes padding and border inside that width.

Do not accept the edit only because it resembles this snippet. Check the actual diff. The prompt limits file scope, but model output still requires review.

## 4. Verify browser and build behavior

Verify all of these before keeping the change:

1. At 390 pixels, no horizontal scrollbar appears and 24-pixel outer padding remains visible.
2. At desktop width, the panel stops growing at 520 pixels.
3. Button, heading, copy, colors, and markup remain unchanged.
4. `git diff -- app/runtime-context/page.module.css` contains only the intended sizing edit.
5. Run your project's normal lint, test, and `next build` checks.

Next.js applies CSS updates immediately during development through Fast Refresh, but its documentation recommends checking the production build because CSS output and ordering can differ between development and production.

## What runtime context contributed

This bug is solvable from source alone. Runtime context reduces ambiguity about which rendered element, route, and viewport the request concerns. Frontman's distributed flow is:

1. Browser tools inspect the selected element and current page.
2. The Frontman server sends relevant task context to your selected AI provider and orchestrates tool calls.
3. File reads and edits execute on your machine through the Next.js integration.
4. Next.js refreshes the preview after the edit.
5. You inspect the rendered result and git diff.

Frontman does not prove the edit is correct, run every project check, or replace code review. It supplies runtime evidence to a normal development workflow.

Continue with [annotations](/docs/using/annotations/) or review [Frontman's limitations](/docs/using/limitations/) before using it on larger changes.
