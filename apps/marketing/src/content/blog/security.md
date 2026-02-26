---
title: 'How Frontman Keeps Your Code Safe'
pubDate: 2026-02-17T05:00:00Z
description: 'Frontman runs only in development, never touches production, and every change produces a reviewable code diff. Here is our security model.'
author: 'Frontman Team'
image: '/blog/security-cover.png'
tags: ['security', 'open-source']
---

You already let AI agents edit your codebase. Cursor writes directly to your files. Claude Code runs shell commands. Copilot suggests code inline and you tab-accept it without reading every line. That is the reality of how developers work now.

So when you hear "Frontman edits your source files," the question is not _whether_ you trust an agent to touch your code. You already made that call. The question is what constraints are in place when it does.

Here is every hard question you should ask, and our answers.

### Where Does It Run?

Frontman runs exclusively in your local development environment. It is a dev dependency. It never ships to production. It never runs in CI. It never touches your deployed application.

The framework integrations — Next.js, Astro, Vite — activate only when `NODE_ENV=development`. In a production build, Frontman's code is not included. Not disabled. Not present. The tree-shaker removes it because nothing imports it outside of dev mode.

This is not a toggle. It is a compile-time guarantee. Frontman _cannot_ run in production because the code does not exist in the production bundle.

### What Can It Change?

Your source files. That is it.

Frontman edits the same files you edit, in the same working directory, tracked by the same Git repository. This is the same model as Cursor or Claude Code — direct file edits. Every change produces a standard diff:

```bash
$ git diff
diff --git a/src/components/Hero.tsx b/src/components/Hero.tsx
index 3a1f2c8..7b4e9d1 100644
--- a/src/components/Hero.tsx
+++ b/src/components/Hero.tsx
@@ -12,7 +12,7 @@
-    <div className="p-4 max-w-2xl mx-auto">
+    <div className="p-6 max-w-2xl mx-auto">
```

That diff shows up in `git status`. It goes through your normal PR review. If it is wrong, `git checkout -- src/components/Hero.tsx` undoes it. No hidden state, no shadow copies, no parallel universe where the agent's version of your code diverges from yours.

**The change _is_ the code.** It cannot drift because it is not stored anywhere else.

### What Does the AI Agent See?

Your code context — the components, styles, and DOM information relevant to the current edit — is sent directly to the AI provider you choose. Frontman does not proxy this. It does not store it. It does not log it.

You bring your own API key. You pick your provider:

- **Claude** via Anthropic
- **ChatGPT** via OpenAI
- **OpenRouter** for access to multiple models

Your key is stored securely in Frontman's server database, encrypted at rest. It is never exposed to the browser. The request goes from Frontman's server to the AI provider using your key, and the result is streamed back to your browser. This is the same trust model you already accepted when you pasted your API key into Cursor's settings or configured Claude Code with your Anthropic key.

### What Can It Not Do?

This list matters more than the feature list:

- It cannot deploy code
- It cannot access production environments
- It cannot run arbitrary shell commands
- It cannot modify files outside your project directory
- It cannot bypass your Git hooks or CI checks
- It cannot merge its own PRs

That last point is worth emphasizing. Cursor and Claude Code can both run `git push` if you let them. Frontman produces diffs. Humans review and ship those diffs. That boundary is not a limitation — it is the design.

### Open Source and Auditable

Frontman is fully open source. Every prompt template, every tool call, every edit operation is visible in the repository. You can audit exactly what the agent sees and what actions it can take.

- **Source**: [github.com/frontman-ai/frontman](https://github.com/frontman-ai/frontman)
- **License**: Apache 2.0 (client libraries), AGPL v3 (server)

If you do not trust a claim on this page, read the code. That is the point of open source.

### Common Objections

**"What if the agent writes malicious code?"**
Then your code review catches it. The same way it catches a bad suggestion from Copilot that you tab-accepted without reading, or a subtle bug in a Cursor-generated function. Frontman does not bypass your review process. It feeds into it. If you are shipping AI-authored code without review, the agent is not your biggest problem.

**"What about API key security?"**
Your API key is stored encrypted in Frontman's server database. It never touches your browser. Requests to your chosen AI provider are made server-side over HTTPS, so the key is never exposed in client-side code or network traffic visible to the browser. This is a stronger security posture than storing a key in a `.env` file or your Cursor config.

**"What if it edits the wrong file?"**
You see the diff immediately. Hot-reload shows you the result in the browser in the same action. If it is wrong, you undo it. This is less risky than a blind agent edit from Cursor, where you accept the change and then have to manually switch to the browser to verify. Frontman shows you the visual result before you decide to keep it.

**"Can I restrict which files it can edit?"**
Yes. Frontman edits source files in your project directory. It does not touch `node_modules`, config files outside the project root, or files in `.gitignore`. You can further constrain it through your `agents.md` conventions — the same file your other agents already read.

### The Security Model in One Sentence

Frontman is a dev tool that produces diffs. It runs locally, sends context to your chosen AI provider, edits your source files, and gets out of the way. Everything else — review, testing, deployment — is your existing workflow, unchanged.

The better world looks like this: a designer changes the hero padding, a developer reviews a one-line diff in the PR, and nobody spent a single second worrying about whether the AI touched something it should not have. Because the constraints are structural, not behavioral. The agent _cannot_ deploy. It _cannot_ push. It produces a diff. You review it. Same as everything else.

Security model changes do not page anyone at 3am.

[Get started with Frontman](/blog/getting-started/) in under five minutes, or read about [why coding agents are blind to your UI](/blog/ai-coding-agents-blind-to-ui/).
