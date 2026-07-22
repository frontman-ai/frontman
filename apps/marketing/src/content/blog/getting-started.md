---
title: 'Frontman Quickstart: First UI Edit'
pubDate: 2026-02-15T05:00:00Z
description: 'Install the Frontman integration for Next.js, Vite, or Astro, open the /frontman workspace, connect an AI provider, and make your first UI edit.'
author: 'Danni Friedland'
image: '/blog/getting-started-cover.png'
imageAlt: 'Frontman quickstart guide for making a first UI edit'
articleSection: 'Tutorial'
tags: ['tutorial', 'getting-started']
updatedDate: 2026-07-20T00:00:00Z
---

By the end of this tutorial, you will have installed Frontman, signed in, connected an AI provider, selected a button in your running app, and asked Frontman to edit its source code.

### Prerequisites

- A Node.js version supported by your framework
- A project using Next.js 13.2-16, Vite 5 or later, or Astro 5-7 on Node.js 22.19 or newer
- A running dev server (`npm run dev` or equivalent)
- A Frontman account; sign-in uses GitHub or Google OAuth
- An Anthropic or OpenAI account, or an API key for a supported provider

### Step 1: Install Frontman

Stop your dev server, then run the command for your framework from the project root.

**Next.js:**
```bash
npx @frontman-ai/nextjs install
```

**Vite (React, Vue, or Svelte):**
```bash
npx @frontman-ai/vite install
```

**Astro:**
```bash
npx astro add @frontman-ai/astro
```

These commands install the framework-specific package and wire Frontman into the development server. The files changed depend on the framework:

| Framework | Files added or updated |
|---|---|
| Next.js 16 | `package.json`, your lockfile, `proxy.ts`, and `instrumentation.ts` or `src/instrumentation.ts` |
| Next.js 13-15 | `package.json`, your lockfile, `middleware.ts`, and `instrumentation.ts` |
| Vite | `package.json`, your lockfile, and `vite.config.ts`, `.js`, `.mts`, or `.mjs` |
| Astro | `package.json`, your lockfile, and `astro.config.mjs` or equivalent |

Run `git diff` after installation and review these changes before continuing.

These compatibility ranges describe the current packages published to npm. Repository support can land before a new package release, so use the published package metadata as the source of truth.

If your Next.js 16 project uses a `src/` directory, the current installer creates `proxy.ts` at the project root. Move it to `src/proxy.ts` before restarting the dev server. Next.js only loads the proxy from the same level as your `app/` or `pages/` directory.

### Step 2: Restart Your Dev Server

Start your project as usual:

```bash
npm run dev
```

After installation, open `/frontman` on the same origin as your app:

- Next.js default: `http://localhost:3000/frontman`
- Vite default: `http://localhost:5173/frontman`
- Astro default: `http://localhost:4321/frontman`

Frontman opens as a full-page workspace with chat on the left and a live preview of your app on the right. If your dev server uses another port, keep that port and append `/frontman`.

### Step 3: Sign In

On your first visit, Frontman shows a welcome dialog and redirects you to sign in. Complete GitHub or Google OAuth. After authentication, you return to the `/frontman` workspace.

### Step 4: Connect an AI Provider

Frontman requires a provider before chat is enabled. In the provider setup dialog, click **Connect AI provider**. The **Providers** settings tab supports:

- **Anthropic Claude Pro/Max** through account authorization, or an Anthropic API key
- **OpenAI** through account authorization
- **NVIDIA**, **Fireworks AI**, or **OpenRouter** with an API key

Connect one provider, then choose an available model in the chat composer. Provider credentials are saved to your Frontman account; they are not written into your project files.

### Step 5: Select and Change a Button

In the chat composer, click **Select**. The control changes to **Selecting…** and your cursor becomes a crosshair over the live preview. Click a button in the preview. Frontman adds the selected element to your prompt with its DOM, source, style, and screenshot context when available.

Now type:

```text
Make this button use our primary color
```

Send the prompt. Frontman inspects the selected element and project context, edits the relevant source file, and lets your framework's hot reload update the preview.

The exact diff depends on your project. A Tailwind button change might look like this:

```diff
- <button className="bg-gray-600 text-white px-4 py-2 rounded">
+ <button className="bg-primary text-white px-4 py-2 rounded">
    Get Started
  </button>
```

The diff is in your working tree. Run `git diff` to see it. This is a normal code change — your team reviews it like any other PR.

### Step 6: Iterate or Commit

If the result is not quite right, describe what is off:

```text
Use the darker shade — primary-700
```

Frontman applies the correction. Keep iterating until it looks right, then commit the change.

### What Just Happened

You selected a live UI element inside the `/frontman` workspace, described a change in plain English, and Frontman:

1. Captured the selected element and its rendered context
2. Resolved source and component information exposed by your framework
3. Used your connected provider to plan and apply the edit
4. Wrote the change to your normal working tree
5. Let your framework's hot reload show the result

The result is real source code that goes through your normal review process.

### Next Steps

- [Installation guide](/docs/installation/)
- [Next.js integration](/docs/integrations/nextjs/)
- [Vite integration](/docs/integrations/vite/)
- [Astro integration](/docs/integrations/astro/)
- [API keys and providers](/docs/api-keys/)
- [What Frontman can and cannot do](/blog/frontman-launch/) — capabilities, tradeoffs, and how it fits into your team's workflow
- [How Frontman compares to Cursor and Claude Code](/blog/frontman-vs-cursor-vs-claude-code/)
- [Security model](/blog/security/) — how Frontman handles your source code
