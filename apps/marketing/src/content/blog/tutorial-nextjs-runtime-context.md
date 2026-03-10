---
title: 'Add Runtime Context to Your AI Workflow (Next.js)'
pubDate: 2026-02-23T07:00:00Z
description: 'Step-by-step: install Frontman in a Next.js project, connect your AI key, and fix a CSS layout bug by clicking the broken element instead of describing it.'
author: 'Danni Friedland'
image: '/blog/tutorial-nextjs-runtime-context-cover.png'
tags: ['tutorial', 'getting-started', 'ai']
updatedDate: 2026-03-10T00:00:00Z
---

This is a practical walkthrough. We'll take a Next.js app with a layout bug, install Frontman, and fix the bug by clicking the broken element in the browser instead of describing it to an AI that can't see it.

By the end you'll know whether runtime-aware AI coding actually saves time or is just a debugger with extra steps. Spoiler: it's both.

### Prerequisites

- A Next.js 14 or 15 project (or `npx create-next-app@latest` to create one)
- An API key from Claude, OpenAI, or OpenRouter
- 5 minutes

### Step 1: Install Frontman

```bash
npx @frontman-ai/nextjs install
```

That's it for setup. Start your dev server:

```bash
npm run dev
```

When you open your app in the browser, navigate to `localhost:3000/frontman`. You'll see the Frontman interface — chat on the left, your live app on the right. Enter your AI key (Claude, OpenAI, or OpenRouter). The key is stored locally in your browser and sent directly to your AI provider.

### Step 2: The Bug

Here's a card grid component with a subtle problem:

```tsx
// src/components/CardGrid.tsx
export function CardGrid({ items }: { items: Item[] }) {
	return (
		<div className="grid grid-cols-3 gap-6 p-8">
			{items.map((item) => (
				<div key={item.id} className="rounded-lg bg-white p-6 shadow-sm">
					<h3 className="text-lg font-semibold">{item.title}</h3>
					{item.featured && (
						<span className="mt-2 inline-block rounded-full bg-blue-100 px-3 py-1 text-sm text-blue-800">
							Featured
						</span>
					)}
					<p className="mt-4 text-gray-600">{item.description}</p>
				</div>
			))}
		</div>
	)
}
```

Looks fine in source code. But when 2 of 6 items are `featured`, the cards with the badge are taller than the ones without. The bottom row doesn't align. The `gap-6` interacts with the conditional badge in a way that isn't obvious from reading the JSX.

### What Cursor Would Do

You'd describe the bug: "The cards in CardGrid aren't aligning properly — some are taller than others."

The AI reads the source, sees `grid-cols-3 gap-6`, and suggests `h-full` on the cards (might work, might cause other issues), `min-h-[200px]` (arbitrary, fragile), or restructures the component entirely (overkill). It can't see that the actual problem is the conditional featured badge pushing content down. The AI is guessing because it doesn't see the rendered layout.

### Step 3: Fix It With Runtime Context

With Frontman running, open the page in your browser. You can see the misaligned cards.

**Click the misaligned card.** Frontman highlights it and shows you the component location (`CardGrid` at `src/components/CardGrid.tsx:5`), the computed styles (actual padding, dimensions, flex/grid properties), the parent layout (grid container with resolved gap, column widths, and row heights), and the children (including the conditional badge).

Now describe the fix:

> "Make all cards the same height and align the description text at the bottom, regardless of whether the Featured badge is present."

Frontman sends the AI your description, the source code, the computed layout showing actual height differences, and the component tree context. The AI generates a targeted edit — adding `flex flex-col` to the card wrapper and `mt-auto` to the description paragraph. It knows this is the right fix because it can see the _actual_ height difference.

The edit is applied to your source file. Hot reload shows the result immediately. Cards align.

### What Happened Under the Hood

```text
1. You clicked an element in the browser
2. Frontman's client-side code identified the React component
   and resolved it to a source file:line via sourcemaps
3. The click target + component info were sent to
   Frontman middleware running inside the Next.js dev server
4. The middleware gathered:
   - Source code of the component
   - Computed styles from the browser
   - Component tree (parent/child relationships)
   - Server-side context (routes, module graph)
5. All packaged as MCP tool responses alongside your description
6. The AI generated a source code edit
7. The edit was written to disk
8. Next.js HMR hot-reloaded the change
9. The browser updated — you see the fix immediately
```

The AI didn't guess what the layout looks like. It _knew_ — because Frontman gave it the computed layout data from the browser.

### Beyond CSS

The card grid example is simple. More realistic scenarios where runtime context helps:

**Debugging a 404.** Your page returns a 404 but the file exists. Ask Frontman "Why is /api/users/me returning 404?" — it gives the AI access to the registered route table and middleware state. The AI can see that a middleware redirect is firing before the route matches.

**Fixing a hydration mismatch.** A component renders differently on server and client. Click the component — Frontman shows the server-rendered HTML vs the client-rendered DOM, plus the source location. The AI sees the mismatch directly.

**Understanding an unfamiliar codebase.** Click the dashboard sidebar. Frontman tells you: `DashboardLayout > Sidebar` at `src/layouts/DashboardLayout.tsx:23`. Answer in 2 seconds instead of grepping through the component tree.

### When NOT to Use This

Runtime-aware AI coding is not a silver bullet:

- **Complex state logic** — the visual output doesn't tell you if your reducer is correct
- **Performance optimization** — Frontman sees the DOM, not your render cycles or bundle size
- **As a substitute for understanding your code** — if you can't explain the AI's diff to a colleague, don't commit it

The runtime context gap is real, and closing it saves time on a specific class of problems. It doesn't replace engineering judgment. It just means the AI guesses less.

[Get started with Frontman](https://frontman.sh) — works with Next.js, Astro, and Vite. Or [see how it compares to Cursor and Claude Code](/blog/frontman-vs-cursor-vs-claude-code/). For a detailed feature-by-feature breakdown, see [Frontman vs Cursor](/vs/cursor/).
