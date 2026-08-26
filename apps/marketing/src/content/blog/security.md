---
title: "Frontman's AI Coding Agent Security Model"
seoTitle: 'AI Coding Agent Security Model'
pubDate: 2026-02-17T05:00:00Z
description: 'A due-diligence guide to Frontman’s browser, server, provider, filesystem, persistence, legal, and human-review boundaries.'
author: 'Danni Friedland'
articleSection: 'Technical Explainer'
image: '/blog/security-cover.png'
imageAlt: 'Frontman AI coding agent security model cover'
tags: ['security', 'open-source']
updatedDate: 2026-07-30T00:00:00Z
faq:
  - question: 'Is Frontman safe to use?'
    answer: 'No development tool can be guaranteed safe for every environment. Frontman separates browser tools, local filesystem tools, server orchestration, and external AI-provider processing. Teams should assess those boundaries, connected providers, data categories, deployment configuration, and generated diffs against their own threat model before use.'
  - question: 'Does Frontman run in production?'
    answer: 'The JavaScript integrations are intended for development workflows, but Next.js middleware or proxy code can remain active in a production build unless you add an environment guard or remove it. The WordPress plugin is a live-site integration and can mutate production WordPress data. Verify deployed routes, restrict access, test built artifacts, and use staging or current backups before production changes.'
  - question: 'What does the AI agent see when using Frontman?'
    answer: 'Depending on the task and tools used, Customer Content can include prompts, source-code snippets, project files, DOM and component information, computed CSS, screenshots, logs, routes, source maps, build errors, metadata, tool results, generated output, and task history. Relevant content passes through the Frontman server to the customer-selected AI provider.'
  - question: 'Can Frontman edit any file on my system?'
    answer: 'Frontman file tools resolve paths under the source root exposed by the framework integration, and the hosted server has no direct filesystem access. Treat this as one control, not a complete sandbox: review the configured root, integration version, available tools, symlink and repository layout, and resulting git diff before approving changes.'
  - question: 'What if Frontman writes bad code?'
    answer: 'Generated edits can be incorrect, incomplete, insecure, or unsuitable. Frontman does not remove the need for source review, tests, security checks, backups, branch protection, CI, and deployment approval. Reject or revert changes that do not pass those controls.'
---

Security review should start with data flow and authority, not a yes-or-no label. In the JavaScript integrations, browser tools inspect the running page and file tools execute through a framework integration on the machine that owns the project. In WordPress, tools execute inside the authenticated live site and mutate WordPress data rather than a local source tree. A hosted or self-hosted server orchestrates the agent loop and persists task history, and a customer-selected AI provider generates responses and tool calls.

This guide maps those boundaries to evidence you can inspect. It is not a certification, penetration-test report, warranty, or guarantee that Frontman is appropriate for your environment.

## Evidence set for due diligence

Review current sources before adoption because software, infrastructure, providers, and policies change:

- [Architecture documentation](/docs/reference/architecture/) for execution environments, tool routing, and persistence
- [Tool capabilities](/docs/using/tool-capabilities/) for exposed browser and dev-server operations
- [Limitations and workarounds](/docs/using/limitations/) for visibility and execution limits
- [Source repository](https://github.com/frontman-ai/frontman) for implementation and package licenses
- [Security policy](https://github.com/frontman-ai/frontman/blob/main/SECURITY.md) for supported versions, scope, and private vulnerability reporting
- [Privacy Policy](/privacy/) for data categories, retention, hosting, diagnostics, and credentials
- [Data Processing Agreement](/dpa/) and [Technical and Organizational Measures](/toms/) for business-customer processing terms and stated controls
- [Subprocessor list](/subprocessors/) for hosted-service dependencies
- [Terms of Use](/terms/) for customer responsibilities, provider boundaries, output limitations, and warranty terms

Repository visibility lets you inspect claims; it does not establish that your deployed instance is correctly configured or free of vulnerabilities.

## Data-flow boundaries

### 1. Browser

The browser client hosts chat and the live preview. Browser-side tools can inspect the preview DOM, take screenshots, search visible text, navigate, interact with elements, and change device mode. Their visibility is limited to the preview context described in [Limitations](/docs/using/limitations/); other tabs, DevTools, and cross-origin iframe content are not generally exposed through those tools.

Risk questions:

- Can previews contain customer, employee, authentication, or production-derived data?
- Are screenshots, DOM text, URLs, or browser logs likely to contain secrets or personal data?
- Do users understand which page state is being attached to a task?

### 2. JavaScript dev server and filesystem

For Next.js, Astro, and Vite, file and project tools execute through the framework integration. The Frontman server relays requests but does not directly mount your filesystem. Current read, write, and edit tools resolve requested paths under the integration's configured source root; edits to existing files also require a prior read in the active tool process.

That narrows authority but does not make generated edits trustworthy. The tools can modify source under the exposed root. Review:

- configured project and source roots;
- monorepo and symlink behavior;
- package version and enabled tool registry;
- OS permissions of the dev-server process;
- untracked files and secrets located inside the exposed root;
- git diff plus changes to generated or ignored files.

Frontman's current agent toolset has no general-purpose terminal tool. Internal implementation may invoke fixed subprocesses for specific features such as search or Lighthouse; that is different from granting the model arbitrary shell access. Verify the current tool registry rather than relying on this page indefinitely.

### 3. Frontman server

The hosted or self-hosted Phoenix server handles authentication, credential resolution, agent orchestration, WebSocket transport, tool routing, and persistence. Task interactions are persisted in PostgreSQL before broadcast, including messages, tool calls, tool results, pauses, retries, and completion events.

For the hosted service, the [Privacy Policy](/privacy/) states that conversation and task history remains until user deletion, with deleted data potentially retained in backups for up to three months. It also states that hosted infrastructure is in the European Union on Hetzner. Confirm contractual and regional requirements against current legal documents before onboarding sensitive projects.

### 4. AI provider

Frontman uses customer-selected providers. Relevant prompts, code context, screenshots, logs, metadata, tool results, and generated output can pass through the Frontman server to that provider. Provider terms, retention, training controls, data location, availability, and security are separate review items controlled partly by your provider account and contract.

The [Terms](/terms/) and [DPA](/dpa/) assign customers responsibility for selecting providers, configuring provider-side controls, and ensuring they are authorized to transmit Customer Content. Do not assume bring-your-own-key means content bypasses Frontman's hosted server.

## Credentials and authentication

The hosted-service [Privacy Policy](/privacy/#api-keys-and-credentials) states that stored API keys and provider credentials use server-side application-level encryption. Authorized personnel and systems may access or decrypt credentials when needed to provide, secure, maintain, troubleshoot, or support the service.

Before adoption:

1. Use provider credentials dedicated to Frontman where the provider supports it.
2. Apply least privilege, spend limits, usage alerts, and rotation procedures.
3. Review Frontman account authentication and offboarding.
4. For JavaScript integrations, test access to `/frontman` and related endpoints in development, preview, and production builds. For WordPress, restrict `/frontman` to intended administrators and protect administrator sessions.
5. Do not place secrets in prompts, screenshots, filenames, URLs, logs, DOM text, or source files exposed to the tool root.

No encryption statement eliminates endpoint compromise, access-control mistakes, provider risk, or accidental disclosure through submitted content.

## JavaScript development and production boundary

The Next.js, Astro, and Vite integrations are designed for development workflows and do not deploy customer code. That product intent is not a substitute for deployment verification.

For each framework and release:

1. Inspect installer changes to middleware, proxy, instrumentation, and dependencies.
2. Build the application with production settings.
3. Confirm whether Frontman client code or routes are present and whether they are reachable.
4. Apply network and authentication controls appropriate to any reachable route.
5. Keep code deployment, secrets, production credentials, and approval authority outside the agent workflow.

Next.js needs particular attention: the [installer templates](https://github.com/frontman-ai/frontman/blob/main/libs/frontman-nextjs/src/cli/FrontmanNextjs__Cli__Templates.res) write middleware for supported Next.js 15.x releases (15.5 minimum) or a proxy for Next.js 16.x. Those generated handlers and matchers contain no `NODE_ENV` guard. Next.js 15.x middleware declares the Node.js runtime; Next.js 16.x proxy uses its supported default runtime because the generated proxy omits the runtime field. If the files remain in a production build, Frontman request handling can remain present. Add an explicit environment guard or remove the integration for deployment, then build and test the deployed artifact. Avoid absolute claims such as “cannot exist in production” unless your own artifact and controls prove that statement.

## WordPress live-site threat model

WordPress is not a source-code development integration. When the plugin is active on a production site, `/frontman` and tool calls run against that site's database, media library, caches, and optional Elementor or WooCommerce data. The router requires a valid WordPress login with `manage_options`; POST tool calls also require the Frontman WordPress nonce. Those checks limit who can invoke tools, but an authorized or compromised administrator session can still cause live customer-facing and business-data changes.

The plugin [registers its core tools](https://github.com/frontman-ai/frontman/blob/main/libs/frontman-wordpress/frontman.php) and conditionally registers Elementor and WooCommerce tools when those plugins are available. Current mutation classes include:

- creating, duplicating, updating, trashing, or permanently deleting posts and pages;
- updating, inserting, moving, or deleting Gutenberg blocks;
- uploading media;
- creating, assigning, updating, moving, or deleting classic and block-theme menus, menu items, and widgets;
- updating allowlisted site options, replacing Additional CSS, updating block templates/template parts, and clearing supported plugin or object caches;
- when Elementor is active, replacing page data and adding, updating, duplicating, moving, removing, restoring, or CSS-flushing Elementor elements;
- when WooCommerce is active, creating or changing products, taxonomy terms, variations, reviews, orders, notes, refunds, customers, shipping, tax, coupon, payment, settings, metadata, and system-status data, plus deletion where a delete tool exists.

Confirmation is selective, not a transaction boundary. Core WordPress delete tools require `confirm=true`; Additional CSS replacement, full Elementor page replacement, Elementor element removal, and Elementor rollback restoration also require confirmation. Granular creates and updates generally execute without that confirmation field. WooCommerce `PUT` and `DELETE` operations and metadata writes require `confirm=true`, while WooCommerce `POST` creates do not. Confirmation records user intent before one tool call; it does not provide multi-call approval, database isolation, or protection against a mistaken confirmed payload.

Rollback is also selective. [Elementor page-data and element mutations](https://github.com/frontman-ai/frontman/blob/main/libs/frontman-wordpress/tools/class-tool-elementor.php) save private snapshots, retain at most 20 per post, and expose list/restore tools. Other WordPress tools often return before/after values and WordPress may provide trash or revisions, but Frontman exposes no general rollback transaction for posts, blocks, menus, widgets, templates, options, media, cache clears, or WooCommerce mutations. Permanent deletes and external effects such as refunds can require recovery outside Frontman. Use staging for broad changes, take application-and-database backups, verify restore procedures, and review each live mutation before approval.

## Human and delivery controls

For JavaScript integrations, Frontman can write files; it does not make those changes safe to merge. Minimum controls should include:

- isolated branches or worktrees;
- clean working-tree snapshots or backups before broad edits;
- review of tracked and untracked changes;
- project tests, linting, type checks, and security scanning;
- branch protection and independent approval for sensitive code;
- separate deployment credentials and production access;
- incident and rollback procedures.

Git improves visibility and recovery for tracked files, but it does not automatically capture ignored files, untracked files, external side effects, or secrets already disclosed to a provider.

These source-control controls do not cover WordPress database or media mutations. Apply the WordPress staging, backup, access, confirmation, and restore controls above separately.

## Licensing boundary

Do not classify the entire system from one package. Frontman uses package-specific licenses. Check the license files in the [repository](https://github.com/frontman-ai/frontman) and the [AI Supplementary Terms](https://github.com/frontman-ai/frontman/blob/main/AI-SUPPLEMENTARY-TERMS.md) that apply to server use. Legal review should use the exact component, version, deployment model, and intended use.

## Adoption checklist

Before approving Frontman for a team, document answers to these questions:

1. Which repositories, roots, routes, users, and environments are in scope?
2. Which data may appear in source, prompts, DOM, screenshots, logs, and history?
3. Will the hosted server or a self-hosted server be used, and where will it store data?
4. Which AI provider account and data terms apply?
5. Which subprocessors and transfer regions are acceptable?
6. How are provider credentials limited, rotated, and revoked?
7. What code-review, CI, branch-protection, and deployment controls remain mandatory?
8. How will production builds be checked for Frontman routes and assets?
9. Who handles deletion, offboarding, incidents, and vulnerability reports?
10. What evidence must be re-reviewed after upgrades or architecture changes?

## Reporting vulnerabilities

Follow Frontman's [Security Policy](https://github.com/frontman-ai/frontman/blob/main/SECURITY.md). Report vulnerabilities through [GitHub private vulnerability reporting](https://github.com/frontman-ai/frontman/security/advisories/new), not a public issue. The policy lists the latest version as supported and identifies server, client libraries, and protocol code as in scope.

Security outcome depends on Frontman's current code, your configuration, connected providers, submitted data, surrounding controls, and user decisions. Evaluate all of them; no architecture diagram or marketing page can provide an absolute guarantee.
