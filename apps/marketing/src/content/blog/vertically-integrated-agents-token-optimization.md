---
title: 'Vertically Integrated Agents Are Better at Token Optimization'
seoTitle: 'Token Optimization for AI Agents: Why Vertical Integration Wins'
pubDate: 2026-06-29T13:00:00Z
description: 'Why vertically integrated agents use fewer requests and fewer tokens by starting with runtime context, source mapping, and verification built into the workflow.'
author: 'Danni Friedland'
authorRole: 'Co-founder, Frontman'
image: '/blog/vertically-integrated-agents-token-optimization-cover.png'
imageWidth: 1200
imageHeight: 450
imageAlt: 'Vertically integrated agent workflow showing browser runtime, dev server tools, and model token optimization'
tags: ['ai-agents', 'developer-tools', 'token-optimization', 'frontend']
faq:
  - question: 'What is token optimization for AI agents?'
    answer: 'Token optimization for AI agents means reducing wasted input tokens, output tokens, requests, retries, and inference cost without removing the context the model needs to do the task correctly.'
  - question: 'Why do vertically integrated agents use fewer tokens?'
    answer: 'Vertically integrated agents start with runtime context, source mapping, logs, tools, and verification already connected. The model spends fewer requests rediscovering where it is, what app it is editing, and whether the result worked.'
  - question: 'Is token optimization the same as counting tokens?'
    answer: 'No. Counting tokens is useful for budgets and limits. Token optimization is broader: it changes the workflow so the agent needs fewer turns, fewer retries, and less repeated context during real work.'
  - question: 'What should teams measure besides token usage?'
    answer: 'Measure requests, input tokens, output tokens, reasoning tokens, cached prompt tokens, non-cached prompt tokens, failed tool calls, retries, and whether the final result was verified in the runtime that mattered.'
  - question: 'Does vertical integration always reduce token usage?'
    answer: 'No. It helps most when the task depends on runtime state, browser behavior, source mapping, logs, or visual verification. For pure backend refactors or small isolated functions, a file-first agent may be enough.'
---

Token optimization is usually described as a prompt problem. Shorter system prompt. Smaller context window. Better retrieval. Count tokens before inference. Watch the usage dashboard. Trim old messages.

All of that helps. None of it is the whole story.

For coding agents, a large part of token usage comes from architecture. A file-only agent has to spend requests reconstructing the world around the code: where the app lives, what framework is running, which route is visible, which component rendered the clicked element, what the browser is doing, what the dev server logged, and whether the change actually worked.

A vertically integrated agent starts with more of that world already connected.

That is why vertical integration is such a strong token optimization strategy. It does not make the model smarter. It gives the model fewer things to guess, fewer things to ask, and fewer failed paths to recover from.

## What Token Optimization Means for Agents

For a single API call, token optimization means managing the input, output, and model limits. You count tokens, estimate the request size, and avoid sending more content than the model can use.

For an agent, token optimization is larger than one API request.

An agent works through a loop:

```text
observe -> plan -> act -> evaluate -> repeat
```

Each pass through that loop can add input tokens, output tokens, reasoning tokens, tool results, error messages, and repeated context. A task that needs 50 requests will usually cost more than the same task solved in 15 requests, even if each individual request is well compressed.

So the useful question is not only:

```text
How many tokens are in this request?
```

It is:

```text
How many requests did the architecture force the agent to make?
```

That is where vertically integrated agents become interesting.

## What Vertically Integrated Means

A vertically integrated coding agent is connected across the layers where work actually happens. It is not just a chat box over files. It has a working relationship with the browser, the dev server, the source tree, the tool runner, the model provider, and the review surface.

In Frontman's case, the vertical path looks like this:

```text
Browser runtime
  -> DOM, screenshots, computed styles, selected elements, viewport state

Framework dev server
  -> routes, logs, source mapping, file reads, file edits, project structure

Frontman server
  -> agent loop, model calls, tool routing, task history, streaming updates

User review
  -> hot reload, visible result, source diff, normal engineering approval
```

That stack gives the model a better starting point. Runtime context is not buried in a paragraph the user has to write. Source mapping is not an inference problem. Verification is not a manual note pasted back into chat. The agent can ask the system for the exact data it needs.

Token optimization follows from that.

## Where File-Only Agents Burn Tokens

File-only agents are powerful. They can read code, edit files, run commands, and reason through large changes. But when the task depends on a running application, they spend tokens bridging missing layers.

Common waste looks like this:

- The user explains the app structure because the agent started at the wrong directory.
- The agent reads broad file trees because it does not know which app or route matters.
- The model infers browser state from source code instead of inspecting runtime state.
- The user translates visual feedback into file-oriented instructions.
- The agent runs a build, but cannot verify the actual browser behavior.
- A wrong edit creates another request, another explanation, another retry.

Every one of those turns adds token usage. The problem is not that the model is verbose. The problem is that the workflow is asking the model to reconstruct context that already exists somewhere else.

This is the difference between counting tokens and optimizing tokens. Counting tokens can tell you a request is large. It cannot tell you why the agent needed 40 requests before it had enough runtime data to act.

## Local Context Before Model Context

The strongest token optimization move is not always compression. Sometimes it is relocation.

Do not send the model a long explanation of the page when the browser can provide a DOM snapshot. Do not ask the user to describe a layout issue when the agent can inspect computed styles. Do not paste server errors into the prompt when the dev server integration can expose logs as a tool. Do not ask the model to guess which file rendered a button when source mapping can answer it.

Use local context before model context.

That principle changes the token budget. Instead of feeding the model a large, lossy description, the agent can call a smaller, structured tool at the moment it needs the data. The API request gets more relevant input tokens. The output tokens go toward the actual change, not another round of discovery.

This is especially important for frontend work. Source files say `p-4 md:p-8`. The browser knows the active viewport and the final computed padding. Source files show a component. The browser knows which DOM node the user clicked. The dev server knows which route is registered and which source file produced the rendered element.

Vertical integration lets the agent use those facts directly.

## Case Study: Same Code Quality, Different Token Usage

We saw this in a small internal case study. We gave the same real frontend task to Frontman, OpenCode, and Claude Code: integrate `astro-consent` into the Frontman marketing site.

All three agents completed the task. The first implementation quality was roughly the same. The difference was token usage and request count.

| Agent | Requests | Prompt tokens | Completion tokens | Reasoning tokens | Total tokens | Cost |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Frontman | 18 | 1,388,944 | 8,114 | 2,073 | 1,399,131 | $1.354412 |
| OpenCode | 56 | 3,625,774 | 13,497 | 4,401 | 3,643,672 | $3.472750 |
| Claude Code | 86 | 5,223,274 | 21,127 | 6,021 | 5,250,422 | $5.472750 |

On that task, Frontman used 68% fewer requests than OpenCode and 79% fewer requests than Claude Code. It used 62% fewer total tokens than OpenCode and 73% fewer total tokens than Claude Code.

The honest takeaway is narrow. Frontman did not prove it writes better code. It proved that, for a runtime-dependent frontend task, a vertically integrated agent can reach and verify a similar result with fewer requests because the environment starts closer to the problem.

The model still matters. Prompt quality still matters. Cache behavior, provider routing, and pricing still matter. But the architecture around the model mattered too.

## Why Runtime Context Saves Requests

Runtime context cuts token usage by removing translation steps.

Without runtime context, the user or agent has to turn visible state into text:

```text
The banner is on the marketing site. It is Astro. The analytics script is here.
The consent package should wrap this. The banner should appear on first visit.
After clicking accept, local storage should change. Now run the build.
```

That explanation becomes input tokens. If it is incomplete, the model makes a wrong request. If the result cannot be checked in the browser, the next human message becomes more input tokens.

With runtime context, the agent can ask narrower questions:

```text
get current route
read Astro config
inspect browser local storage
click accept button
check visible banner state
```

Each request is grounded. The agent does not need a long prompt to know the page exists. It can see the page. It does not need the user to count tokens in every message. It needs the system to stop generating unnecessary messages.

That is real token optimization.

## Counting Tokens Still Matters

Vertical integration does not replace basic token discipline.

Teams should still count tokens before large inference calls when the provider supports it. They should still watch the usage dashboard. They should still track input tokens, output tokens, and total token usage. They should still inspect usage data from the API response when the API returns it. They should still set stream options carefully if streaming affects how usage data appears.

But counting tokens is instrumentation, not strategy.

If a usage dashboard shows a task burned too many tokens, the next question should be architectural:

- Did the agent read too many files because it lacked route context?
- Did it repeat the same project summary in every request?
- Did it need the user to paste browser errors that tools could have fetched?
- Did it run inference before gathering local context?
- Did it retry because it could not verify the runtime result?

The best token optimization work happens before the model call. It shapes what the agent knows, when it knows it, and which tool can answer instead of another prompt.

## What to Measure

If you are evaluating agent token optimization, do not stop at total token usage.

Track at least this:

| Metric | Why it matters |
| --- | --- |
| Requests | More requests usually mean more repeated context and more chances to drift. |
| Input tokens | Shows how much context the model needed each turn. |
| Output tokens | Shows how much text, code, and tool planning the model generated. |
| Reasoning tokens | Important for models that expose separate reasoning usage. |
| Cached prompt tokens | Helps separate reusable context from fresh cost. |
| Non-cached prompt tokens | Better proxy for expensive repeated context. |
| Failed tool calls | Often signal missing context or weak tool boundaries. |
| Retries | Retry count is hidden token waste. |
| Runtime verification | A build pass is not always proof the visible behavior worked. |

The pattern matters more than one number. A low token count with no verification is not automatically better. A high token count that prevents a production bug may be worth it. Token optimization should reduce waste, not remove evidence.

## Vertical Integration Is Not Magic

There are limits.

Vertical integration helps most when the task depends on browser state, dev-server state, logs, routes, source mapping, user-visible behavior, or hot reload. It matters less for small pure functions, isolated backend refactors, or tasks where tests are the only meaningful oracle.

It can also add setup cost. A framework integration has to be installed. Tool boundaries have to be designed. The agent needs permission rules. The system needs to decide which data belongs in the browser, which data belongs in the dev server, and which data should reach the model.

Bad vertical integration can make token usage worse. If the harness dumps every DOM node, every log line, every route, and every file into every request, it has not optimized anything. It has moved waste from user prompts into tool output.

Good vertical integration is selective. It keeps context local until needed. It sends structured facts instead of noisy transcripts. It lets the model call tools instead of carrying the whole world in the prompt.

## Checklist for Agent Builders

If you are building a coding agent and care about token optimization, ask these questions:

- Can the agent discover the current app, route, framework, and working directory without asking the user?
- Can it inspect runtime state before spending input tokens describing runtime state?
- Can it map visible UI back to source files without guessing?
- Can logs, build errors, and API response data be fetched as tools instead of pasted into chat?
- Can the agent verify the result in the same environment where the bug appeared?
- Can the model request narrow context instead of receiving a giant default context blob?
- Can the system count tokens, requests, retries, and failed tool calls per task?
- Can the user still review a small source diff before anything ships?

If the answer is yes, token optimization becomes a property of the whole system. Not a prompt trick. Not a dashboard chore. A workflow advantage.

## The Better Token Optimization Story

The next wave of agent optimization will not only be smaller prompts. It will be better placement of context.

Some context belongs in the browser. Some belongs in the dev server. Some belongs in a tool result. Some belongs in the model input. Some should never leave the user's machine. Vertically integrated agents can make those choices because they own more of the loop.

That is why they are so good at token optimization. They reduce the number of times the model has to ask, infer, retry, and explain. They replace broad guesses with narrow evidence. They make token usage follow the real shape of the task.

For frontend work, that shape starts in the running application.

[Try Frontman](/#install) on a real frontend task, then compare the requests, total tokens, and verified result against your current coding agent.
