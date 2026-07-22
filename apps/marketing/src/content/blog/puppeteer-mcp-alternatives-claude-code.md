---
title: 'Best Puppeteer MCP Alternatives for Claude Code Browser Debugging'
seoTitle: 'Puppeteer MCP Alternatives for Claude Code'
pubDate: 2026-07-16T00:00:00Z
description: 'Compare Chrome DevTools MCP, Playwright MCP, Claude in Chrome, and Frontman for Claude Code browser debugging, DOM access, automation, and source mapping.'
author: 'Danni Friedland'
authorRole: 'Co-founder, Frontman'
authorUrl: '/authors/danni-friedland/'
image: '/blog/puppeteer-mcp-alternatives-claude-code-cover.png'
imageWidth: 1200
imageHeight: 450
imageAlt: 'Comparison of Puppeteer MCP alternatives for Claude Code browser debugging'
articleSection: 'Comparison or Buyer Guide'
tags: ['comparison', 'claude-code', 'browser-automation', 'developer-tools']
comparisonItems:
  - name: 'Chrome DevTools MCP'
    url: 'https://github.com/ChromeDevTools/chrome-devtools-mcp'
    description: 'Debugging-focused Chrome integration with console, network, performance, screenshot, and page inspection tools.'
  - name: 'Playwright MCP'
    url: 'https://github.com/microsoft/playwright-mcp'
    description: 'Cross-browser automation server built around structured accessibility snapshots and deterministic interactions.'
  - name: 'Claude in Chrome'
    url: 'https://code.claude.com/docs/en/chrome'
    description: 'Anthropic browser integration for Claude Code with shared login state, DOM access, console inspection, and browser actions.'
  - name: 'Frontman'
    url: 'https://frontman.sh/'
    description: 'Frontend agent that connects live browser evidence to project files, framework state, source locations, and hot reload.'
faq:
  - question: 'What is the best Puppeteer MCP alternative for Claude Code?'
    answer: 'Based on their documented capabilities, Chrome DevTools MCP is the strongest default for debugging a Chrome page with console messages, network requests, screenshots, performance traces, and page inspection. Playwright MCP is better suited to repeatable cross-browser automation, while Claude in Chrome requires less setup for supported Anthropic plans.'
  - question: 'Can Claude Code inspect the DOM?'
    answer: 'Yes. Claude Code can read DOM state through Claude in Chrome or an external browser server such as Chrome DevTools MCP or Playwright MCP. The representation differs: some tools expose accessibility snapshots, while JavaScript evaluation can query the live DOM directly.'
  - question: 'Was Puppeteer MCP deprecated?'
    answer: 'The original @modelcontextprotocol/server-puppeteer reference server moved into the Model Context Protocol archived servers repository, which GitHub marked read-only on May 29, 2025. Puppeteer itself remains an active browser automation library, and independent Puppeteer MCP servers may still be maintained.'
  - question: 'Is Chrome DevTools MCP better than Playwright MCP?'
    answer: 'Chrome DevTools MCP is the better fit for Chrome-specific debugging and performance analysis. Playwright MCP is the better fit for repeatable automation across Chromium, Firefox, and WebKit. Both can inspect page state, read console messages, inspect network activity, take screenshots, and interact with pages.'
  - question: 'Does browser DOM access tell Claude Code which source file rendered an element?'
    answer: 'Not automatically. DOM and accessibility snapshots describe rendered page structure, not necessarily the framework component, source file, or line that produced it. That requires source metadata, framework integration, source maps, or separate codebase investigation.'
---

Your app renders. The checkout button is visible. Clicking it does nothing.

Claude Code can read the component, search the repository, and edit the handler. But the useful evidence is in the running browser: the disabled attribute that appeared after hydration, the console exception, the failed network request, and the DOM state after the click.

That is why developers installed Puppeteer MCP. It gave a coding agent a browser it could navigate, inspect, and control. The original reference server is now archived, and the replacement landscape is better than a simple fork.

**Quick answer:** Based on current documented capabilities, Chrome DevTools MCP is the best fit for Claude Code browser debugging. Playwright MCP is better suited to repeatable cross-browser automation. Claude in Chrome is the lowest-setup option if your Anthropic plan supports it. Frontman is narrower: use it when the task starts from a rendered element and must end in the correct frontend source file.

This is not a generic list of [browser-aware AI coding tools](/blog/what-are-browser-aware-ai-coding-tools/). It answers one question: **which browser connection should you give Claude Code when you need DOM access and debugging evidence?**

Source status checked: July 16, 2026. Browser integrations change quickly. This comparison uses the current [Claude Code Chrome documentation](https://code.claude.com/docs/en/chrome), [Chrome DevTools MCP repository](https://github.com/ChromeDevTools/chrome-devtools-mcp), [Microsoft Playwright MCP repository](https://github.com/microsoft/playwright-mcp), and archived [Model Context Protocol Puppeteer server](https://github.com/modelcontextprotocol/servers-archived/tree/main/src/puppeteer).

Disclosure: I built Frontman, one of the options below. Frontman is not a drop-in MCP server for Claude Code, and this guide does not pretend it is. Chrome DevTools MCP and Playwright MCP are stronger choices for several workflows.

## How We Evaluated These Alternatives

This is a documentation-based capability comparison, not a benchmark. We counted a capability only when current official documentation or the project's published tool reference described it. We treated undocumented behavior as unknown rather than assuming that a browser integration could expose it.

The comparison asks four questions: what browser can the tool control, what runtime evidence can it retrieve, what security boundary does it create, and whether it can connect a rendered element to application source. The [reproducible test below](#a-reproducible-browser-debugging-test) is the next step for evaluating behavior in a specific environment; this article does not present that proposed test as completed evidence.

### What evidence exists for Frontman?

Frontman's claims are inspectable in its [public repository](https://github.com/frontman-ai/frontman), documentation, and source links throughout this guide. On July 16, 2026, GitHub showed 612 stars, 38 forks, 699 commits, and nine contributors. Those numbers demonstrate public interest and activity, not product quality.

There is also evidence outside Frontman's website. Gerald Chen published an independent [technical analysis of Frontman's browser-first architecture](https://chenguangliang.com/en/posts/blog159_frontman-frontend-ai-agent/) on May 1, 2026, including limitations around React Server Components, runtime CSS-in-JS, production debugging, and hot reload. An independently submitted [Hacker News discussion](https://news.ycombinator.com/item?id=47898441) drew a small and appropriately skeptical response; four points and three comments are a mention, not broad validation.

Our [Frontman versus OpenCode versus Claude Code case study](/blog/frontman-vs-opencode-claude-code-case-study/) reports prompts, requests, token counts, costs, implementation quality, browser verification, and limitations from one real Astro task. It is first-hand evidence for Frontman's workflow, but it tested a consent-banner integration rather than the browser-debugging scenario in this article. It therefore does not validate the rankings below.

WordPress.org currently lists five five-star reviews for Frontman's separate WordPress plugin. One review was posted by Frontman co-founder Itay Adler, so we do not represent the aggregate as five independent customer reviews. The other public reviews describe time saved on legacy-site updates, block and settings changes, and visual editing, but they concern the WordPress integration rather than Claude Code browser debugging.

## What Happened to Puppeteer MCP?

The phrase "Puppeteer MCP deprecated" needs precision.

The original `@modelcontextprotocol/server-puppeteer` package was a reference MCP server. It exposed navigation, screenshots, CSS-selector clicks, hover, form filling, JavaScript evaluation, and console logs through Puppeteer. Its last package metadata in the archived repository lists version `0.6.2`.

The [repository containing that server](https://github.com/modelcontextprotocol/servers-archived/tree/main/src/puppeteer) was archived and made read-only on May 29, 2025. That makes the original server a poor default for a new setup: no active repository means no normal path for fixes, dependency upgrades, browser compatibility work, or security maintenance.

Puppeteer itself was not deprecated. It remains an active browser automation library. Chrome DevTools MCP even uses Puppeteer for reliable browser automation while adding deeper DevTools-oriented tools. Independent projects may also publish maintained servers under similar names.

The replacement decision is therefore not "Puppeteer or no browser." It is which maintained integration matches the work:

- Debug a live Chrome page.
- Automate a repeatable flow across browsers.
- Reuse an authenticated browser with minimal configuration.
- Connect a rendered element back to framework and source context.

## Puppeteer MCP Alternatives at a Glance

| Option | Best use | Browser coverage | DOM access | Console and network | Performance tooling | Source mapping |
| --- | --- | --- | --- | --- | --- | --- |
| Chrome DevTools MCP | Chrome debugging and performance analysis | Google Chrome and Chrome for Testing | Accessibility snapshot plus JavaScript evaluation | Yes | Traces, insights, Lighthouse, memory tools | Browser stack traces only; no framework component mapping |
| Playwright MCP | Repeatable browser automation and exploratory testing | Chromium, Firefox, WebKit, Edge | Accessibility snapshot plus JavaScript evaluation | Yes | Not its primary default workflow | No framework component mapping |
| Claude in Chrome | Low-setup browser work from Claude Code | Chrome and Edge | Yes | Yes | No equivalent full DevTools trace workflow documented | No framework component mapping documented |
| Frontman | Local frontend debugging and browser-to-source edits | Embedded project preview | DOM, CSS selectors, computed styles via JavaScript | Console output during browser tool execution plus framework build/server logs; no full DevTools console or network inspector | Lighthouse audits | Framework-aware source file and line detection |
| Archived Puppeteer MCP | Basic selector-driven automation | Chromium through Puppeteer | CSS selectors plus JavaScript evaluation | Console logs; no dedicated network request tools | No | No |

All five can put browser evidence into an agent loop. They do not provide the same evidence.

## What Claude Code Browser Debugging Actually Requires

"Browser access" hides several different capabilities.

### Browser automation

Can the agent open a URL, click a button, fill a field, switch tabs, and wait for a result? Puppeteer MCP, Playwright MCP, Chrome DevTools MCP, and Claude in Chrome all cover this layer.

Automation answers: "Can Claude reproduce the checkout failure?"

### Claude Code DOM access

Can the agent inspect what rendered instead of inferring it from JSX or templates? An accessibility snapshot is a text representation of page roles, labels, content, and interactive controls. JavaScript evaluation can query `document`, attributes, computed styles, event state, and application globals directly.

DOM access answers: "Is the button disabled after hydration?"

### DevTools evidence

Can the agent inspect console messages, failed requests, response details, source-mapped browser stack traces, performance traces, and memory behavior? Chrome DevTools MCP is built around this layer. Playwright MCP and Claude in Chrome expose useful console and network evidence, but Chrome DevTools MCP has the deepest debugging and performance surface.

DevTools evidence answers: "Did the click throw, or did the request return 401?"

### Framework and source context

Can the agent connect `<button class="checkout">` back to `src/components/CheckoutButton.tsx:42`, identify its React or Vue component, read framework routes and build logs, edit the source, then observe hot reload?

This is separate from DOM access. The browser knows the rendered node. It does not inherently know which abstraction in your source tree owns the fix. Source mapping is the connection from that rendered element to the component file and line that produced it. The missing connection is part of the [runtime context gap](/blog/runtime-context-gap/).

Framework context answers: "Which file should change, and did the dev server accept the edit?"

## 1. Chrome DevTools MCP: Best Fit for Browser Debugging

[Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) has the strongest documented fit when your query is literally "Claude Code browser debugging."

Install it for your user account:

```bash
claude mcp add chrome-devtools --scope user npx chrome-devtools-mcp@latest
```

Then ask Claude Code to inspect a running page:

```text
Open http://localhost:3000/checkout. Click the Place order button.
Inspect console errors and failed network requests, then explain why
the confirmation state does not render. Do not edit files yet.
```

Google's current [Chrome DevTools MCP tool reference](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md) lists:

- Page navigation, tabs, clicks, form filling, keyboard input, and waits.
- Accessibility-tree snapshots and screenshots.
- JavaScript evaluation in the selected page.
- Console message inspection, including source-mapped browser stack traces.
- Network request lists and request details.
- Performance recording and trace insights.
- Lighthouse audits.
- Optional heap snapshot and memory debugging tools.
- Device and viewport emulation.

Chrome DevTools MCP starts a dedicated Chrome profile by default. It can also connect to a running Chrome instance through automatic connection or a remote debugging endpoint. That is useful when the bug depends on application state you established manually.

### Where Chrome DevTools MCP is stronger than Puppeteer MCP

The archived Puppeteer server offered basic automation, screenshots, JavaScript execution, and console logs. Chrome DevTools MCP adds first-class network inspection, performance traces, Lighthouse, source-mapped console stack traces, emulation, and optional memory tools.

It is not "Puppeteer replaced by a completely different mechanism." Chrome DevTools MCP uses Puppeteer internally for automation. The difference is the maintained server and the debugging surface exposed around it.

### Chrome DevTools MCP limitations

- Official support targets Google Chrome and Chrome for Testing. Other Chromium browsers may work but are not guaranteed.
- It sees browser state, not your framework's server-side route table, module graph, or build process.
- An accessibility snapshot or DOM query does not automatically identify the owning source component.
- Browser access can expose authenticated pages, tokens visible to page JavaScript, private application data, and anything open in the connected profile.
- Usage statistics are enabled by default. The project documents `--no-usage-statistics` for opting out.
- Performance traces may query the Google CrUX API with the inspected URL unless you disable that behavior with `--no-performance-crux`.

For sensitive work, prefer an isolated profile: a separate or temporary browser profile without your normal cookies, history, and authenticated sessions. Restrict reachable URLs and avoid connecting an agent to your everyday browser profile.

## 2. Playwright MCP: Best Fit for Repeatable Automation

[Microsoft Playwright MCP](https://github.com/microsoft/playwright-mcp) has the strongest documented fit when the job is closer to testing than DevTools investigation.

Install it in Claude Code:

```bash
claude mcp add playwright npx @playwright/mcp@latest
```

Its default interaction model uses structured accessibility snapshots. Claude receives stable element references and acts on those references instead of guessing coordinates from screenshots. That makes flows such as registration, checkout, search, and navigation deterministic enough for repeated use.

Microsoft's current [Playwright MCP tool reference](https://github.com/microsoft/playwright-mcp#tools) exposes tools for:

- Navigation, tabs, clicks, hover, drag and drop, keyboard input, and forms.
- Accessibility snapshots and screenshots.
- Console message retrieval.
- Network request lists, headers, and response bodies.
- JavaScript evaluation.
- Viewport resizing and device emulation.
- Persistent profiles, isolated sessions, saved storage state, and connection to existing Chrome or Edge tabs.
- Chromium, Firefox, WebKit, and Edge selection.

Run it headless when no visible browser is needed:

```bash
npx @playwright/mcp@latest --headless
```

### Where Playwright MCP is stronger than Puppeteer MCP

Cross-browser coverage is the obvious difference. The official Playwright MCP server also has a maintained accessibility-snapshot workflow, richer session configuration, network inspection, and clearer isolation controls than the archived Puppeteer reference server.

It is particularly good for a prompt such as:

```text
Test the signup flow in Chromium and Firefox at 390px wide.
Use a fresh isolated session for each browser. Report differences in
validation messages, focus order, and the final network request.
```

### Playwright MCP limitations

- Accessibility snapshots prioritize semantic interaction, not visual fidelity. Screenshots remain necessary for spacing, clipping, color, and responsive composition.
- Browser automation still does not provide framework source mapping.
- Persistent browser profiles can conflict when concurrent clients use the same workspace.
- Microsoft explicitly says Playwright MCP is not a security boundary.
- Its `browser_run_code_unsafe` tool is described as remote-code-execution equivalent. Do not enable or approve arbitrary code against untrusted instructions.
- The Playwright project now recommends its CLI plus skills for many coding-agent workflows because large MCP schemas and accessibility trees consume context. MCP remains useful when persistent browser state and iterative page inspection matter.

## 3. Claude in Chrome: Best for Lowest Setup

Claude Code now has an official browser path. Start it with:

```bash
claude --chrome
```

Or run `/chrome` inside an existing session.

[Claude in Chrome](https://code.claude.com/docs/en/chrome) connects Claude Code to Anthropic's browser extension. It opens visible tabs and shares the browser's login state, which makes it useful for authenticated applications without exporting cookies into a separate automation profile.

Anthropic's current [Claude Code Chrome documentation](https://code.claude.com/docs/en/chrome#capabilities) lists these capabilities:

- Read DOM state, console messages, and network requests.
- Take screenshots.
- Navigate, click, type, and manage tabs.
- Test local web applications.
- Work with authenticated pages already open to your browser session.
- Pause for manual login or CAPTCHA completion.
- Record browser interactions as GIFs.

This changed the answer to "Can Claude Code see my browser?" Older comparisons that say Claude Code is always browser-blind are now incomplete. Claude Code remains file- and terminal-oriented by default, but `--chrome` adds a first-party browser loop.

### Claude in Chrome limitations

- It requires a direct Anthropic Pro, Max, Team, or Enterprise plan.
- It is unavailable when Claude Code access comes exclusively through Bedrock, Google Cloud's Agent Platform, or Microsoft Foundry.
- Official support covers Chrome and Edge, not Brave, Arc, or other Chromium browsers.
- It is not supported in Windows Subsystem for Linux.
- It shares authenticated browser state. Site permissions deserve careful review.
- Enabling Chrome by default increases context usage because browser tools remain loaded.
- It provides browser evidence, not documented framework component-to-source mapping.

## 4. Frontman: Best for DOM-to-Source Frontend Work

[Frontman](/) is not a Puppeteer MCP server and does not plug into Claude Code. It is a specialized frontend agent with its own browser and framework tool loop.

That narrower architecture matters when the task begins with a specific rendered element. Frontman's [annotation documentation](/docs/using/annotations/) and [tool reference](/docs/using/tool-capabilities/) describe this context:

- The selected element and a generated CSS selector.
- Element screenshot, classes, text, and bounding box.
- React, Vue, or Astro component metadata where available.
- Source file and line through React fiber metadata, Vue component metadata, or Astro development annotations.
- The live preview DOM and JavaScript-computed style values.
- Project files, framework routes where supported, build output, server logs, and hot-reload errors.

The workflow is not "give Claude Code another browser." It is "give a frontend agent a bounded preview and a direct path from pixels to source."

That makes Frontman useful for layout bugs, design-system drift, responsive behavior, copy changes, component variants, and UI work initiated by a designer or PM. It makes Frontman a poor choice for general web automation, scraping, cross-browser test suites, or debugging arbitrary production tabs.

### Frontman limitations

- Frontman sees its embedded project preview, not every tab in your browser.
- It cannot inspect browser DevTools or cross-origin iframes.
- It has no general terminal tool.
- OAuth pop-ups, third-party SSO, and some production authentication flows do not fit its preview boundary.
- Framework and source detection can fail when metadata is unavailable or abstractions hide ownership.
- It does not offer Chrome DevTools MCP's network, performance-trace, or memory-debugging depth.
- It is early-stage and supports a narrower set of frontend frameworks than general browser automation tools.

The [Next.js runtime-context tutorial](/blog/tutorial-nextjs-runtime-context/) shows this specialized loop against one frontend task.

## Claude Code DOM Access Compared

DOM access is not binary. Each tool exposes a different representation and a different route from observation to action.

| Question | Chrome DevTools MCP | Playwright MCP | Claude in Chrome | Frontman |
| --- | --- | --- | --- | --- |
| Can it inspect rendered structure? | Yes, accessibility snapshot and JavaScript | Yes, accessibility snapshot and JavaScript | Yes, documented DOM state tools | Yes, scoped DOM subtree tools and JavaScript |
| Can it select DOM elements? | Through snapshot references or JavaScript selectors | Through snapshot references or selectors | Through browser tools | Through visual annotations, roles, text, CSS selectors, or XPath |
| Can it read computed CSS? | Yes, through JavaScript evaluation | Yes, through JavaScript evaluation | Not explicitly documented | Yes, through JavaScript and annotation context |
| Can it read console errors? | Yes | Yes | Yes | Captures console output from browser tool execution and framework/server logs; not a full DevTools console replacement |
| Can it inspect network requests? | Yes | Yes | Yes | No dedicated network inspector |
| Can it map an element to source? | Not by default | Not by default | Not documented | Yes, when framework metadata resolves |
| Can it edit project files? | Through Claude Code | Through Claude Code | Through Claude Code | Through Frontman's framework tools |
| Can it inspect build/server evidence? | No | No | No | Framework build and server logs, plus routes on supported integrations |

The practical distinction:

```text
DOM access tells the agent what rendered.
DevTools access tells the agent what happened in the browser.
Source mapping tells the agent where the fix belongs.
Framework access tells the agent what happened around the browser.
```

No single option is strongest across all four layers.

## A Reproducible Browser-Debugging Test

Do not compare tools using their homepages. Give each one the same failure.

Create or use a page with these conditions:

1. A button is present in the DOM but disabled after hydration.
2. Clicking the enabled version triggers an API request that returns `401`.
3. A narrow viewport clips the server error message.
4. The button is rendered through a shared component rather than directly in the route.

Then use this prompt:

```text
Open http://localhost:3000/checkout at 390px wide.

Determine why the Place order button cannot complete checkout. Inspect
the rendered element state, console errors, and network requests. Identify
the source component that owns the button and the CSS rule clipping the
error message. Do not edit code. Return evidence for every conclusion and
state which requested evidence you could not retrieve.
```

Score each option on evidence, not whether it eventually guesses the bug:

- Did it inspect the actual disabled state?
- Did it capture the `401` request and response?
- Did it identify the clipping at the requested viewport?
- Did it locate the owning source component without broad repository search?
- Did it distinguish browser evidence from assumptions?
- Did it expose sensitive cookies, headers, or unrelated tabs?

This test separates automation from debugging and debugging from source mapping. It also gives you a repeatable way to re-evaluate tools after releases.

## Security Boundaries Matter More Than Setup Speed

A browser MCP server can act with your browser's authority. That may include authenticated internal tools, customer data, session cookies, local development services, and private network access.

The archived Puppeteer server warned that it could access local files and internal IP addresses. The maintained alternatives add controls, but none turns arbitrary browser automation into a safe sandbox by default.

Before connecting Claude Code to a browser:

- Use a dedicated or isolated browser profile when possible.
- Use tool-specific host, origin, or URL restrictions as defense in depth. They are not complete security boundaries and may not cover redirects or older browser versions.
- Do not expose a remote debugging port beyond localhost.
- Avoid `--no-sandbox`, unrestricted file access, or unsafe code execution unless the environment is disposable.
- Review whether network headers, response bodies, and authenticated page content enter model context.
- Keep secrets out of test fixtures and visible page state.
- Prefer read-only inspection before allowing clicks, typing, uploads, or JavaScript evaluation.

Convenience is not the security model. Read the [AI coding agent security model](/blog/security/) before standardizing a browser-enabled workflow across a team.

## WebMCP Is Not Another Puppeteer MCP Alternative

[WebMCP](/blog/what-is-webmcp/) lets a website declare structured tools for an agent. Browser MCP servers instead give an agent tools that control or inspect sites from outside the page, including sites that never implemented agent-specific tools. Do not install WebMCP expecting browser automation or DevTools inspection.

## Which Puppeteer MCP Alternative Should You Choose?

**Choose Chrome DevTools MCP** when debugging evidence is primary. Console messages, network details, performance traces, Lighthouse, memory analysis, and Chrome-specific behavior are its strongest case.

**Choose Playwright MCP** when repeatable automation is primary. Use it for cross-browser flows, forms, regression checks, isolated sessions, and structured accessibility-driven interaction.

**Choose Claude in Chrome** when setup cost is primary. If your plan and platform qualify, `claude --chrome` may already provide enough DOM access, console inspection, network evidence, screenshots, and interaction for routine work.

**Choose Frontman** when source ownership is primary. Use it for local frontend work where a selected rendered element must resolve to a component, file, line, framework state, and reviewable edit. We built it for that narrower job.

**Keep a maintained Puppeteer-based server** when its exact API, selectors, or launch behavior already fit your automation and someone is actively maintaining it. The problem is not Puppeteer. The problem is standardizing on an archived reference server without an owner.

Start with the smallest tool that retrieves the evidence your bug requires. If browser state is still not enough, read [why source files and runtime state diverge](/blog/runtime-context-gap/). If the task starts from a visible frontend element, run the [Frontman quickstart](/blog/getting-started/) against one real UI bug.
