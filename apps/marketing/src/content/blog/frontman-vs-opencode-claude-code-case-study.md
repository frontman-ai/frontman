---
title: 'Frontman vs OpenCode vs Claude Code: AI Coding Agent Case Study'
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

We recently ran the same real frontend task through three coding agents and compared the traces afterward.

The agents were:

- **Frontman**, running GPT-5.5 with medium thinking
- **OpenCode**, running GPT-5.5 with medium thinking
- **Claude Code**, running Claude Opus 4.7

The task was intentionally ordinary: install a consent-banner package on our marketing site and make it work with the analytics code already there. We wanted normal product work, not a benchmark stunt.

The task: integrate [`astro-consent`](https://github.com/velohost/astro-consent) into the Frontman marketing site, which already had Google Analytics configured.

All three agents completed it. The first implementation was essentially the same in each run. The traces differed in how much exploration and verification happened before completion.

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

Treat the cost numbers carefully. Model pricing, cache accounting, provider routing, and model choice can all change. Claude Code also used a different model. The request and token counts are the safer comparison: Frontman needed fewer agent turns to reach the same outcome.

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

## All Three Finished

This is not a dunk on OpenCode or Claude Code. Both completed the task. Claude Code was especially comprehensive and read broadly through the marketing app to understand the surrounding pages and conventions. OpenCode behaved similarly to Frontman once it had enough context.

The first implementation quality was roughly the same across all three. We would not summarize the run as:

> Frontman wrote better code.

The more accurate summary is:

> Frontman reached and verified the same result with fewer agent turns because it started with more relevant runtime and framework context.

For frontend work, a lot of the cost is not typing the final diff. It is finding the right part of the app, checking the visible result, and iterating without losing context.

## Why Frontman Needed Less Exploration

OpenCode and Claude Code had to discover the application from the filesystem. They were dropped into a monorepo and needed to work out where the marketing app lived, what framework it used, where analytics was configured, how the Astro config was structured, and what build command should verify the result.

Frontman already had a running browser session attached to the marketing app. More importantly, the Frontman Astro integration is not a generic file browser. It is installed inside the Astro dev server.

In this repo, the marketing site uses the Frontman Astro integration directly in [`apps/marketing/astro.config.mjs`](https://github.com/frontman-ai/frontman/blob/main/apps/marketing/astro.config.mjs):

```js
frontman({
  projectRoot: appRoot,
  sourceRoot: monorepoRoot,
  basePath: "frontman",
  serverName: "marketing",
})
```

The agent starts from a narrower state. It is not starting with "what is this repo?" It is already inside a known Astro app, with a live preview and the relevant tool set registered.

The Astro integration only activates in dev mode. It installs middleware into Astro's Vite server, registers a Frontman dev toolbar app, captures source annotations, and exposes Astro-aware tools for routes and logs.

From [`libs/frontman-astro/src/FrontmanAstro__Integration.res`](https://github.com/frontman-ai/frontman/blob/main/libs/frontman-astro/src/FrontmanAstro__Integration.res), the integration does several important things:

- Registers Frontman middleware before Astro page routing, so `/frontman` and tool routes work inside the dev server.
- Injects annotation capture into page heads, so selected DOM elements can be associated with source context where Astro exposes it.
- Adds a Vite plugin that injects component props as HTML comments for richer agent context.
- Initializes log capture, so the agent can see dev-server output and post-edit errors.
- Uses Astro's resolved routes hook on Astro 5 and newer for route discovery.

In this task, that wiring saved discovery work. Frontman did not need to infer from scratch that `apps/marketing` was an Astro app or where the browser-visible result should be checked.

## Browser Verification Changed the Workflow

Verification differed too.

OpenCode ran `make build` and stopped. Claude Code did the same. That is a valid baseline for many code tasks: if the build passes, the integration probably compiles.

Frontman also verified through the browser. It checked that the consent banner was visible, then interacted with the banner using browser-side JavaScript to confirm the buttons worked.

Frontman can do that because it registers browser-side tools in the client, including screenshots and JavaScript execution against the live preview iframe.

In [`libs/client/src/Client__ToolRegistry.res`](https://github.com/frontman-ai/frontman/blob/main/libs/client/src/Client__ToolRegistry.res), Frontman registers browser tools such as:

- `take_screenshot`
- `execute_js`
- `set_device_mode`
- `get_interactive_elements`
- `interact_with_element`
- `get_dom`
- `search_text`
- `question`

For this task, `make build` was necessary but incomplete. The visible behavior mattered: a new user sees the banner, can accept or reject it, and does not keep seeing it after making a choice. Frontman checked the first two pieces in the browser instead of stopping at compile success.

## Where the Extra Turns Went

The first implementation is only part of frontend work. The slow part is often the loop after the code compiles:

```text
try it -> look at it -> notice something off -> adjust -> verify again
```

We did not formally measure that second phase, so it is not in the table. During follow-up banner tweaks, though, the workflow difference was obvious: Frontman could look at the rendered banner and act on it directly. The other tools needed the operator to translate the visible issue back into file-oriented instructions.

That is a smaller claim than "browser agents are better," and it fits the data better.

Without browser context, the user or the agent has to translate visual state into filesystem instructions:

```text
The banner is on the marketing site. It is Astro. The analytics script is over here. The config is over there. The consent package should wrap this. The banner should appear on first visit. Now run the build.
```

With Frontman, some of that context is already present before the first model call. The agent starts closer to the part of the problem that actually changed.

## What the Architecture Bought Us

The useful claim from this run is narrow: runtime and framework context reduced wasted turns.

They did not make the model write a better consent integration. They reduced how much of the conversation was spent locating the app, understanding the framework setup, and checking whether the browser behavior matched the request.

Frontend tasks expose this quickly because the source code is not the only source of truth. The rendered DOM, computed CSS, viewport, local storage, cookies, client-side state, dev-server logs, and route table all matter.

Frontman connects those surfaces through the browser and framework integration:

```text
Browser preview
  -> screenshots, DOM, JavaScript execution, element interaction

Astro dev server
  -> routes, logs, file reads, file edits, source annotations

Frontman server
  -> agent loop, provider calls, tool routing, persisted task history
```

This architecture costs more setup than a pure terminal agent and it is less general. Frontman is not the tool we would choose for a deep backend refactor, a large migration, or a task where visual/runtime feedback does not matter.

For this task, though, the extra wiring removed work that the other agents had to do through exploration.

## What This Does Not Prove

This was a case study, not a scientific benchmark:

- It was one task on one repo.
- The repo was Frontman's own marketing app, which means the setup naturally favored Frontman's harness.
- Frontman did not produce better first-pass code. All three agents produced roughly the same implementation.
- Claude Code used a different model than Frontman and OpenCode.
- We did not use wall-clock time as the metric because network conditions and inference speed make it noisy.
- OpenCode had browser tooling available but did not use it during this run.
- Browser context matters much less for backend work, pure refactors, or tasks where build/test output is the main source of truth.

We would call it evidence for one narrow thing: on a real frontend integration task, browser and framework context reduced the number of agent turns needed to reach and verify the same result.

## What We Took From The Run

The result changed how we talk about Frontman internally. We should not claim that browser context automatically produces better code. This run did not show that.

It showed something more practical: when the task depends on a running frontend, the agent wastes fewer turns if the running frontend is part of its normal working environment.

The model still matters. The prompt still matters. For frontend work, this run suggests the environment around the model matters too.

[Try Frontman](https://frontman.sh/#install) on your own frontend task and compare the loop yourself.
