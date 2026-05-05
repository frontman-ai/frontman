---
title: 'What Happened When We Ran the Same Frontend Task in Frontman, OpenCode, and Claude Code'
pubDate: 2026-05-05T05:00:00Z
description: 'A single-task case study comparing Frontman, OpenCode, and Claude Code on the same Astro consent-banner integration. Same final code quality, very different iteration and token profiles.'
author: 'Danni Fridland'
authorRole: 'Co-founder, Frontman'
image: '/blog/ai-coding-tools.png'
tags: ['case-study', 'ai-agents', 'developer-tools', 'astro']
faq:
  - question: 'Did Frontman produce better code than OpenCode or Claude Code in this case study?'
    answer: 'No. All three agents completed the task and produced roughly the same initial implementation. The interesting result was efficiency: Frontman required fewer model requests, fewer tokens, and less verification handoff because it already had runtime and framework context.'
  - question: 'Is this a scientific benchmark?'
    answer: 'No. This is a single-task internal case study on one real repo task. It is useful evidence for how architecture affects agent efficiency, not a universal claim that one agent is always better than another.'
  - question: 'Why was Frontman more efficient?'
    answer: 'Frontman is integrated into the running Astro dev server and browser preview. It already knew it was operating inside an Astro site, had access to the app structure through the integration, and could verify the banner visually through screenshots and browser-side JavaScript.'
---

We recently ran a small internal case study: give the same real frontend task to three coding agents and compare what happened.

The agents were:

- **Frontman**, running GPT-5.5 with medium thinking
- **OpenCode**, running GPT-5.5 with medium thinking
- **Claude Code**, running Claude Opus 4.7

The task was deliberately mundane. No heroic refactor. No architecture rewrite. No contrived benchmark prompt. We wanted something that looked like real product work on our own marketing site.

The task: integrate [`astro-consent`](https://github.com/velohost/astro-consent) into the Frontman marketing site, which already had Google Analytics configured.

All three agents completed it. All three produced essentially the same first implementation. The difference was not code quality.

The difference was how much work each agent needed to get there.

## The Result

| Agent | Requests | Prompt tokens | Completion tokens | Reasoning tokens | Total tokens | Cached prompt tokens | Non-cached prompt tokens | Cost |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Frontman | 18 | 1,388,944 | 8,114 | 2,073 | 1,399,131 | 1,296,384 | 92,560 | $1.354412 |
| OpenCode | 56 | 3,625,774 | 13,497 | 4,401 | 3,643,672 | 3,345,408 | 280,366 | $3.472750 |
| Claude Code | 86 | 5,223,274 | 21,127 | 6,021 | 5,250,422 | 5,145,408 | 105,014 | $5.472750 |

On this task, Frontman used:

- **68% fewer requests than OpenCode**
- **79% fewer requests than Claude Code**
- **62% fewer total tokens than OpenCode**
- **73% fewer total tokens than Claude Code**
- **61% lower reported cost than OpenCode**
- **75% lower reported cost than Claude Code**

Treat the cost numbers carefully. Model pricing, cache accounting, provider routing, and model choice can all change. Claude Code also used a different model. The more durable signal is the request and token profile: Frontman needed fewer agent turns to reach the same outcome.

That is the point of the case study.

## The Task

The exact Frontman prompt was:

```text
help me integrate https://github.com/velohost/astro-consent to this page
```

For OpenCode and Claude Code, the prompt had to be slightly more explicit because they were operating from the monorepo rather than from the browser context of the marketing app:

```text
help me integrate https://github.com/velohost/astro-consent to @apps/marketing/
```

The site already had Google Analytics. The agents needed to install and configure `astro-consent`, adjust the analytics setup so consent mattered, add the banner styling, and make sure the site compiled and worked.

The user-visible behavior was simple: a new visitor should see a consent banner until they accept or reject it. After that choice, the banner should not keep appearing.

## The Important Part: All Three Finished

This is not a dunk on OpenCode or Claude Code. Both completed the task. Claude Code was especially comprehensive and read broadly through the marketing app to understand the surrounding pages and conventions. OpenCode behaved similarly to Frontman once it had enough context.

The first implementation quality was roughly the same across all three.

That matters, because the honest conclusion is not:

> Frontman wrote better code.

The honest conclusion is:

> Frontman reached and verified the same result with fewer agent turns because it started with more relevant runtime and framework context.

For frontend work, that distinction is the product.

## Why Frontman Needed Less Exploration

OpenCode and Claude Code had to discover the application from the filesystem. They were dropped into a monorepo and needed to work out where the marketing app lived, what framework it used, where analytics was configured, how the Astro config was structured, and what build command should verify the result.

Frontman already had a running browser session attached to the marketing app. More importantly, the Frontman Astro integration is not a generic file browser. It is installed inside the Astro dev server.

In this repo, the marketing site uses the Frontman Astro integration directly in `apps/marketing/astro.config.mjs`:

```js
frontman({
  projectRoot: appRoot,
  sourceRoot: monorepoRoot,
  basePath: "frontman",
  serverName: "marketing",
})
```

That gives the agent a much narrower starting point. It is not asking, "what is this repo?" It is operating inside a known Astro app with a live preview, framework tools, and browser tools already registered.

The Astro integration itself is designed around that idea. It only activates in dev mode, installs middleware into Astro's Vite server, registers a Frontman dev toolbar app, captures source annotations, and exposes Astro-aware tools for routes and logs.

From `libs/frontman-astro/src/FrontmanAstro__Integration.res`, the integration does several important things:

- Registers Frontman middleware before Astro page routing, so `/frontman` and tool routes work inside the dev server.
- Injects annotation capture into page heads, so selected DOM elements can be associated with source context where Astro exposes it.
- Adds a Vite plugin that injects component props as HTML comments for richer agent context.
- Initializes log capture, so the agent can see dev-server output and post-edit errors.
- Uses Astro's resolved routes hook on Astro 5 and newer for route discovery.

That is what we mean by "deep integration." It is not only a chat box next to an iframe. The dev server, browser, and agent loop are wired together.

## Browser Verification Changed the Workflow

The verification behavior differed too.

OpenCode ran `make build` and stopped. Claude Code did the same. That is a valid baseline for many code tasks: if the build passes, the integration probably compiles.

Frontman also verified through the browser. It checked that the consent banner was visible, then interacted with the banner using browser-side JavaScript to confirm the buttons worked.

That verification path exists because Frontman registers browser-side tools in the client, including screenshots and JavaScript execution against the live preview iframe.

The relevant tools are not abstract. In `libs/client/src/Client__ToolRegistry.res`, Frontman registers browser tools such as:

- `take_screenshot`
- `execute_js`
- `set_device_mode`
- `get_interactive_elements`
- `interact_with_element`
- `get_dom`
- `search_text`
- `question`

For this task, the browser-specific value was straightforward: the acceptance criterion was not only "Astro builds." The acceptance criterion was "a new user sees a banner, can accept or reject it, and does not keep seeing it after making a choice."

A build can tell you the first half only indirectly. A browser can tell you directly.

## Why This Matters for Iteration

The first implementation is only part of frontend work. The expensive part is often the loop after the implementation:

```text
try it -> look at it -> notice something off -> adjust -> verify again
```

We did not formally measure that second phase in this case study, so we are not including it in the table. But qualitatively, the same pattern held. Minor banner adjustments were faster in Frontman because the agent could operate from the rendered page and immediately verify the change in the browser.

That is where browser-aware agents become interesting. The advantage is not that they are smarter. It is that they remove a pile of translation work.

Without browser context, the user or the agent has to translate visual state into filesystem instructions:

```text
The banner is on the marketing site. It is Astro. The analytics script is over here. The config is over there. The consent package should wrap this. The banner should appear on first visit. Now run the build.
```

With Frontman, some of that context is already part of the harness. The agent starts closer to the task.

## The Architecture Claim

The result supports a specific architectural claim:

> Runtime and framework context are efficiency features.

They do not magically make the model more intelligent. They reduce the amount of exploration, prompting, and verification the model has to spend tokens on.

This is especially visible in frontend work because the source code is not the only source of truth. The rendered DOM, computed CSS, viewport, local storage, cookies, client-side state, dev-server logs, and route table all matter.

Frontman connects those surfaces through the browser and framework integration:

```text
Browser preview
  -> screenshots, DOM, JavaScript execution, element interaction

Astro dev server
  -> routes, logs, file reads, file edits, source annotations

Frontman server
  -> agent loop, provider calls, tool routing, persisted task history
```

That architecture is more setup than a pure terminal agent. It is also less general. Frontman is not the tool we would choose for a deep backend refactor, a large migration, or a task where visual/runtime feedback does not matter.

But for a frontend task whose correctness is visible in the browser, the integration pays for itself.

## Caveats

This was a case study, not a scientific benchmark.

The caveats are real:

- It was one task on one repo.
- The repo was Frontman's own marketing app, which means the setup naturally favored Frontman's harness.
- Frontman did not produce better first-pass code. All three agents produced roughly the same implementation.
- Claude Code used a different model than Frontman and OpenCode.
- We did not use wall-clock time as the metric because network conditions and inference speed make it noisy.
- OpenCode had browser tooling available but did not use it during this run.
- Browser context matters much less for backend work, pure refactors, or tasks where build/test output is the main source of truth.

Those caveats do not make the result meaningless. They make the conclusion narrower and more useful.

This case study does not prove that Frontman is universally better than OpenCode or Claude Code. It shows that, for a real visual/frontend integration task, deep browser and framework integration reduced the number of agent turns needed to reach and verify the same result.

## The Takeaway

The interesting result is not that Frontman completed the task. So did the other agents.

The interesting result is that Frontman completed it with fewer requests, fewer tokens, and browser-level verification built into the workflow.

That is what we are building Frontman around: not a bigger model, not a new prompting trick, but a better execution environment for frontend work.

If the task is visual, the agent should be able to see it. If the app is running, the agent should be able to inspect it. If the result matters in the browser, verification should happen in the browser.

[Try Frontman](https://frontman.sh/#install) on your own frontend task and compare the loop yourself.
