---
title: 'Best WordPress MCP Servers and Plugins in 2026'
seoTitle: 'Best WordPress MCP Servers and Plugins 2026'
pubDate: 2026-07-31T05:00:00Z
description: 'Compare WordPress MCP servers and plugins for Claude, ChatGPT, Cursor, content, SEO, WooCommerce, Elementor, security, and custom abilities.'
image: '/blog/best-wordpress-mcp-servers-and-plugins-2026-cover.png'
tags: ['wordpress', 'mcp', 'comparison', 'ai']
comparisonItems:
  - name: 'Royal MCP'
    url: 'https://wordpress.org/plugins/royal-mcp/'
    description: 'Focused WordPress MCP plugin with OAuth, API-key authentication, rate limiting, audit logs, and integrations.'
  - name: 'WordPress MCP Adapter'
    url: 'https://github.com/WordPress/mcp-adapter'
    description: 'Official WordPress package that exposes Abilities as MCP tools, resources, and prompts.'
  - name: 'Easy MCP AI'
    url: 'https://wordpress.org/plugins/easy-mcp-ai/'
    description: 'Free WordPress MCP plugin with broad content, SEO, analytics, and plugin tool coverage.'
  - name: 'StifLi Flex MCP'
    url: 'https://wordpress.org/plugins/stifli-flex-mcp/'
    description: 'Broad WordPress MCP server with tool profiles, OAuth, change tracking, and rollback.'
  - name: 'AI Engine'
    url: 'https://wordpress.org/plugins/ai-engine/'
    description: 'Established WordPress AI framework combining MCP with chatbots, content, forms, and model connectors.'
  - name: 'miniOrange Secure MCP Server'
    url: 'https://wordpress.org/plugins/miniorange-secure-mcp-server/'
    description: 'Governance-oriented MCP plugin with role policies, approval workflows, data rules, and audit logs.'
  - name: 'InstaWP MCP Server'
    url: 'https://github.com/InstaWP/mcp-wp'
    description: 'Node.js MCP server using the WordPress REST API, application passwords, and multi-site configuration.'
faq:
  - question: 'What is the best WordPress MCP server in 2026?'
    answer: 'Based on published controls and adoption as of July 31, 2026, Royal MCP is our starting point for teams seeking a focused WordPress plugin. This is not a tested reliability or security ranking. Use its OAuth flow with a dedicated, appropriately scoped WordPress user; its API-key path runs with administrator capability. Developers exposing custom Abilities should start with the official WordPress MCP Adapter.'
  - question: 'Is there an official WordPress MCP server?'
    answer: 'Yes. The WordPress MCP Adapter is the official WordPress package for exposing WordPress Abilities as MCP tools, resources, and prompts. It supports HTTP and STDIO transports, but it is developer infrastructure rather than a complete site-owner editing product.'
  - question: 'Can Claude or ChatGPT connect to WordPress through MCP?'
    answer: 'Yes. Several WordPress MCP plugins document remote connections for Claude, ChatGPT, Cursor, and other compatible clients. Support and setup differ by client, transport, authentication method, and hosting environment, so verify the current guide for both the plugin and client before deployment.'
  - question: 'Is a WordPress MCP server safe to use on production?'
    answer: 'An MCP server creates a privileged application surface and should not be treated as safe merely because it supports OAuth or application passwords. Start on staging, use a dedicated low-privilege WordPress user, expose the smallest possible tool set, require confirmation for writes, keep backups, log calls, and test revocation before production use.'
  - question: 'Is Frontman a WordPress MCP server?'
    answer: 'No. Frontman is an AI website editor for WordPress with its own agent interface and WordPress-native tools beside a live preview. Choose an MCP server when an external client must call WordPress tools. Choose Frontman when a person needs to make and visually review supported site changes without configuring an external MCP client.'
author: 'Itay Adler'
articleSection: 'Comparison or Buyer Guide'
imageAlt: 'Best WordPress MCP Servers and Plugins in 2026 article cover.'
---

"WordPress MCP server" now describes at least three products: official developer infrastructure, a plugin that gives external AI clients structured WordPress tools, and a broader AI suite that happens to include an MCP endpoint. Comparing them by tool count alone gives you a large number and a bad decision.

**Quick answer:** Start with [Royal MCP](https://wordpress.org/plugins/royal-mcp/) when you want a focused WordPress plugin and can use OAuth with a dedicated, limited-permission user. Developers building custom WordPress tools should start with the official [WordPress MCP Adapter](https://github.com/WordPress/mcp-adapter). If neither describes your job, use the table below to choose by workflow, safeguards, and hosting model.

**Disclosure and evidence status:** We build [Frontman for WordPress](/wordpress/), which appears later as a non-MCP alternative for live-preview editing. [Itay Adler](/authors/itay-adler/), this article's author, is a Frontman co-founder with a full-stack engineering and WordPress product background. This article is not an affiliate roundup. We did not run a hands-on benchmark of every plugin. Product capabilities below are documented claims checked against official WordPress documentation, WordPress.org plugin pages, and public repositories on July 31, 2026. Tool counts, client support, versions, pricing, and authentication flows can change.

## Best WordPress MCP servers and plugins at a glance

| Option                                                                                      | Best for                                                                     | Hosting model                                              | Authentication                                                                          | Main tradeoff                                                                          |
| ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| [Royal MCP](https://wordpress.org/plugins/royal-mcp/)                                       | Focused, ready-to-use WordPress MCP access                                   | Runs inside WordPress                                      | OAuth, or API key with administrator capability; rate limiting and audit log documented | API-key access is highly privileged; no plugin-wide human approval workflow documented |
| [WordPress MCP Adapter](https://github.com/WordPress/mcp-adapter)                           | Developers building custom Abilities and MCP servers                         | WordPress plugin or Composer package; HTTP and local STDIO | WordPress user permissions; application passwords or custom auth for remote HTTP        | Infrastructure, not a finished editing experience                                      |
| [Easy MCP AI](https://wordpress.org/plugins/easy-mcp-ai/)                                   | Content, SEO, analytics, and multi-plugin workflows                          | Runs inside WordPress                                      | OAuth or bearer token with per-token permissions                                        | Very large tool surface increases review and configuration work                        |
| [StifLi Flex MCP](https://wordpress.org/plugins/stifli-flex-mcp/)                           | Broad site operations with documented undo and tool profiles                 | Runs inside WordPress                                      | OAuth 2.1 or application-password fallback                                              | Wide feature surface; verify each advertised integration before relying on it          |
| [AI Engine](https://wordpress.org/plugins/ai-engine/)                                       | Sites already using a broad AI framework                                     | Runs inside WordPress                                      | OAuth with administrator-only access by default, or bearer token                        | Bearer token overrides the default administrator check; several tool groups are Pro    |
| [miniOrange Secure MCP Server](https://wordpress.org/plugins/miniorange-secure-mcp-server/) | Governance, role policies, approvals, and data controls                      | Runs inside WordPress                                      | Self-hosted OAuth 2.1 or API key                                                        | Very new plugin with limited public adoption evidence                                  |
| [InstaWP MCP Server](https://github.com/InstaWP/mcp-wp)                                     | Node.js workflows and managing several WordPress sites from one local server | Separate Node.js process using WordPress REST API          | WordPress application passwords                                                         | You operate another process and its credentials; not a normal WordPress plugin         |

There is no universal winner. Your decision turns on five things: the WordPress actions you need, how the server authenticates clients, whether writes require review, where the server runs, and how you recover from a bad tool call.

Need Claude, ChatGPT, or Cursor to call WordPress tools? Choose an MCP server. Need a person to request a change and review the live page in one workflow? Evaluate [Frontman for WordPress](/wordpress/) instead.

If you cannot explain who approves a write and how you recover it, the server is not ready for production.

## How we evaluated these WordPress MCP options

We reviewed each product's official WordPress.org listing, public repository, documentation, and changelog on July 31, 2026. We did not install every option or run standardized security, reliability, latency, or task-completion tests.

Authorization and permission narrowing carried the most weight because an over-privileged credential can turn one bad tool call into a site-wide incident.

| Criterion                              | Weight | Why it matters                                                            |
| -------------------------------------- | -----: | ------------------------------------------------------------------------- |
| Authorization and permission narrowing |    25% | Limits damage from compromised credentials or incorrect tool calls       |
| Write safeguards                       |    20% | Reduces accidental production changes                                    |
| Recovery                               |    15% | Determines whether failed changes can be inspected and reversed          |
| Task coverage                          |    15% | Confirms support for the WordPress surfaces your workflow needs           |
| Deployment burden                      |    10% | Affects setup, maintenance, and credential handling                       |
| Evidence quality                       |    15% | Separates public code and changelogs from unsupported promotional claims |

We did not assign numerical product scores because we did not test the implementations. Rankings indicate documented fit against these weights, not proven security or reliability.

## Setup, price, and requirements

These are source-checked entry requirements, not estimates of total operating cost. Model usage, hosting, implementation, support, and commercial add-ons can add cost.

| Option                       | Published entry cost                                                                      | Minimum documented environment            | Setup shape                                                                     |
| ---------------------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------- |
| Royal MCP                    | Free GPL plugin; no Pro version documented                                                | WordPress 5.8+, PHP 7.4+                  | Install plugin, choose OAuth or copy an API key, then configure client          |
| WordPress MCP Adapter        | Free GPL package                                                                          | WordPress 6.9+, PHP 7.4+                  | Install release plugin or Composer package; configure HTTP or WP-CLI STDIO      |
| Easy MCP AI                  | Free WordPress.org plugin; no paid tier documented                                        | WordPress 6.0+, PHP 7.4+                  | Install plugin, use OAuth consent or create scoped bearer token                 |
| StifLi Flex MCP              | Free WordPress.org plugin; commercial status not assessed                                 | WordPress 5.9+, PHP 7.4+                  | Install plugin, choose modules and tool profile, then connect through OAuth     |
| AI Engine                    | Free plugin with Pro tool groups                                                          | WordPress 6.0+, PHP 8.1+                  | Install broad AI framework, enable MCP, choose tools and authentication         |
| miniOrange Secure MCP Server | Free WordPress.org plugin; no paid tier documented                                         | WordPress 6.9+, PHP 7.4+                  | Install plugin, define identities and policies, then authorize client           |
| InstaWP MCP Server           | Public Node.js repository; infrastructure cost is yours                                   | Node.js 18+ and WordPress REST API access | Run separate process, configure one or more site URLs and application passwords |

## What a WordPress MCP server actually does

The [Model Context Protocol](https://modelcontextprotocol.io/docs/getting-started/intro) gives an AI client a standard way to discover and call tools and read resources. In WordPress, an MCP tool might retrieve a post, create a draft, update product stock, read an SEO field, or invoke a custom plugin action.

WordPress 6.9 added the [Abilities API](https://developer.wordpress.org/apis/abilities-api/), a registry for typed, discoverable units of functionality. An Ability defines input and output schemas and an execution callback, and it can define a permission callback. The official MCP Adapter's default server exposes eligible public Abilities through discovery, information, and execution tools. Developers can create custom servers that expose selected Abilities directly as MCP tools, resources, or prompts.

That distinction matters:

- The **Abilities API** describes what WordPress or a plugin can do.
- An **MCP adapter or server** exposes selected functionality to compatible AI clients.
- The **AI client** decides when to call a tool.
- WordPress authentication, transport permissions, and any Ability permission callback determine whether the call may execute.
- Your operating process decides whether a human reviews the change before it reaches production.

MCP is plumbing. Useful plumbing, but still plumbing. It does not automatically give an agent accurate Elementor context, safe WooCommerce mutations, visual verification, useful approvals, or reliable rollback.

## 1. Royal MCP: recommended starting point for a focused plugin

[Royal MCP](https://wordpress.org/plugins/royal-mcp/) is our recommended starting point because it covers the connector controls we weighted most heavily. Its WordPress.org page documents authentication on every session, OAuth support, API-key access, per-IP rate limiting, activity logging, sensitive-data redaction, and Streamable HTTP transport.

Authentication paths are not equivalent. Royal's [plugin changelog](https://wordpress.org/plugins/royal-mcp/#developers) states that API-key-authenticated requests run with administrator capability. Use OAuth with a dedicated, lower-privilege WordPress user when that flow supports your client and task. Treat the API key like an administrator credential, not a convenient general-purpose token.

Its tool surface covers normal WordPress content and site operations. Conditional integrations add WooCommerce, Elementor, Advanced Custom Fields, and several Royal Plugins products. Current Elementor tools cover page cloning, text and image replacement, compact page outlines, templates, individual widget settings, and adding registered widgets or containers. That is more capable than the earlier clone-only workflow, but it is not equivalent to safely generating an arbitrary complete Elementor page from unconstrained JSON.

Royal makes sense when you want a self-hosted plugin, a remote MCP endpoint, and practical integrations without installing an all-purpose AI suite. Pass if you require mandatory human approval for every high-risk operation or rollback across all mutations. Revisions and activity logs are not universal transactional rollback.

Royal MCP also has the strongest public adoption signal among the focused plugins checked here: its WordPress.org page reported more than 9,000 active installations on July 31, 2026. Install count is not a security audit, but it is more operational evidence than a newly listed plugin with no reviews.

## 2. WordPress MCP Adapter: best official foundation for developers

The [WordPress MCP Adapter](https://github.com/WordPress/mcp-adapter) is the official WordPress package for bridging the Abilities API to MCP. Its default server provides discovery and execution tools for eligible public Abilities. Custom servers can map selected Abilities directly to tools, resources, or prompts. It supports HTTP, STDIO through WP-CLI, custom transports, permission controls, error handlers, and observability handlers.

Use it when you own plugin code and want precise control over the functions exposed to agents. You can register an Ability with typed schemas and a `permission_callback`, then expose it through the default server or a custom server. Local development can use STDIO through WP-CLI. Remote clients can use HTTP, with the official documentation showing a local `@automattic/mcp-wordpress-remote` proxy and WordPress application passwords.

The Adapter is a strong fit for custom development because each capability contract and permission callback can live beside the WordPress code that owns the operation. Purpose-built Abilities can expose narrower schemas and clearer semantics than generic REST-route access.

Choose it when you are building a plugin, exposing a custom business operation, or need control over transports and observability. It is not a no-code site-management product. The useful domain Abilities still need to exist.

## 3. Easy MCP AI: best for SEO, content, and analytics workflows

[Easy MCP AI](https://wordpress.org/plugins/easy-mcp-ai/) documents a large free tool surface spanning WordPress content, WooCommerce, ACF, events, BuddyPress, six SEO plugins, Google Analytics 4, Google Search Console, and optional third-party SEO data providers.

Its practical differentiator is the combination of publishing operations and measurement data. The documented tools appear capable of reading Search Console queries, updating supported SEO metadata, revising a post, and recording change history without a separate server for each system. We did not verify that sequence. Test those operations together because scopes, plugin compatibility, and write behavior can differ between tools.

The plugin documents OAuth with per-scope consent, bearer tokens, per-token permissions, WordPress capability checks, configurable rate limits, IP allowlisting, an audit trail, before/after change history, and a force-draft setting. Those controls fit editorial workflows better than one unrestricted administrator credential.

Easy MCP AI makes the most sense for a team that wants publishing, SEO, analytics, WooCommerce, and plugin integrations in one workflow. Its large catalog is a liability when you need only basic post editing. Every enabled tool adds configuration, governance, and testing work.

## 4. StifLi Flex MCP: best when rollback is a selection requirement

[StifLi Flex MCP](https://wordpress.org/plugins/stifli-flex-mcp/) documents OAuth 2.1, application-password fallback, tool profiles, WordPress capability checks, confirmations in its built-in agent, more than 100 built-in MCP tools, WordPress Abilities discovery, and integrations for WooCommerce, Elementor, SEO, forms, and code-snippet plugins.

Its clearest differentiator is change tracking. StifLi's [plugin changelog](https://wordpress.org/plugins/stifli-flex-mcp/#developers) documents before-and-after snapshots, one-click undo and redo, and session rollback across more than 60 mutating tools. That is stronger recovery evidence than a generic audit log, but it does not establish universal rollback coverage. Plugin-specific side effects, external API calls, emails, order events, and cache mutations may not be reversible.

Tool profiles are also useful. A read-only WordPress profile or WooCommerce read-only profile is safer than exposing complete site management by default. Profiles reduce accidental breadth, but they do not remove prompt-injection risk or bad decisions inside allowed tools.

StifLi belongs on the shortlist when broad WordPress and WooCommerce operations matter and documented rollback is a hard requirement. It is a poor fit when you want the smallest possible tool surface or need independent proof for every advertised integration. Test rollback on staging before treating it as a production control.

## 5. AI Engine: best when you also need a broad AI framework

[AI Engine](https://wordpress.org/plugins/ai-engine/) is much broader than an MCP connector. It includes chatbots, a WordPress admin workspace, content and media generation, forms, embeddings, model-provider connections, function calling, and developer APIs. MCP belongs inside that larger system.

That breadth makes AI Engine a sensible choice when the site already uses it or needs both visitor-facing AI and external agent access. Its [MCP documentation](https://ai.thehiddendocs.com/mcp/) describes OAuth and bearer-token connections, connected-app revocation, MCP logs, and free WordPress and media tools. Plugin, theme, database, Polylang, and WooCommerce tool groups are Pro. External MCP access is administrator-only by default, while a configured bearer token overrides that default check. Workspace separately requires approval before site-changing actions; do not treat that Workspace approval as a gate for external MCP clients.

AI Engine has a substantially larger installed base than the focused MCP plugins, but installation count does not establish security or correctness. Its [July 2026 plugin changelog](https://wordpress.org/plugins/ai-engine/#developers) lists MCP permission and security fixes, showing that consequential authorization defects existed in recent releases. Review the exact changelog entries, test upgrades on staging, and verify required tools with a non-administrator account before production use.

Choose AI Engine when MCP is one requirement among chatbots, content generation, knowledge bases, forms, and model-provider workflows. Installing the full framework for one endpoint adds configuration and attack surface. Before using bearer authentication, verify which WordPress identity and capabilities the token receives, and check which required tools need Pro.

## 6. miniOrange Secure MCP Server: governance-focused, but early

[miniOrange Secure MCP Server](https://wordpress.org/plugins/miniorange-secure-mcp-server/) presents the broadest vendor-documented governance feature set in this comparison. Its listing claims self-hosted OAuth 2.1, role-based non-human identities, per-tool controls, human approval workflows, data-loss-prevention rules, prompt-injection detection, anomaly detection, quotas, audit logs, and WordPress Abilities support. We did not independently validate those controls.

That feature set maps well to enterprise requirements. It also demands skepticism. On July 31, 2026, WordPress.org reported only 40-plus active installations and no reviews. The plugin is new, and the broadest security and governance claims come from its vendor. We found documentation, not independent validation.

miniOrange is worth a controlled proof of concept when policy enforcement, approval, identity, and audit requirements matter more than public maturity. Before that test, ask how policy failures behave, what gets logged, how audit data is retained or exported, and whether future releases will change feature or pricing boundaries.

## 7. InstaWP MCP Server: best separate Node.js option for multiple sites

The [InstaWP MCP Server](https://github.com/InstaWP/mcp-wp) is different from the PHP plugins above. It runs as a Node.js process and calls one or more WordPress sites through the REST API using application passwords. Its repository documents unified content and taxonomy tools, media, users, comments, plugins, smart URL resolution, and configuration for up to ten sites.

This architecture is useful when an agency wants one local MCP process to target several WordPress installations. It also keeps MCP runtime code outside each site. The cost is another process, another dependency chain, and a credential set for every target site.

The repository documents important limitations instead of hiding them. WordPress silently rejects unregistered post-meta keys through the REST API, so Yoast, Rank Math, and AIOSEO writes do not automatically work. The optional SQL tool requires a custom endpoint and administrator capability. Those boundaries make the recommendation easier to trust.

InstaWP fits developers who prefer Node.js, need a local Claude Desktop workflow, or manage several sites through one process. It does not fit teams that want a dashboard-installed plugin, OAuth consent, or deep builder behavior without additional WordPress code.

## Security matters more than tool count

A WordPress MCP server can turn one model decision into a content update, user change, plugin action, order mutation, or settings write. Authentication is necessary. It is not sufficient.

The [MCP security guidance](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices) recommends least-privilege scopes, per-client consent, exact redirect validation, secure sessions, auditability, HTTPS for production authorization, and protection against token passthrough and server-side request forgery. WordPress adds its own permission layer through users, roles, capabilities, transport permissions, and any permission callback registered for an Ability.

Before connecting Claude, ChatGPT, Cursor, Gemini, or another client to a real site:

1. Create a dedicated WordPress user, preferably with a custom role containing only the required capabilities. Editor, Shop Manager, and Administrator are broad bundles, not least-privilege profiles.
2. Start with read-only tools and drafts. Disable permanent deletion, user and role administration, plugin or theme changes, arbitrary options, code execution, SQL, refunds, order mutations, and credential-bearing diagnostics unless the workflow requires them.
3. Use HTTPS. If the connection uses a WordPress [Application Password](https://developer.wordpress.org/rest-api/using-the-rest-api/authentication/#basic-authentication-with-application-passwords), remember that calls act with the bound user's capabilities.
4. For OAuth, verify PKCE with S256, exact redirect-URI matching, single-use authorization codes, short-lived access tokens, refresh-token rotation or reuse detection, token audience validation, and explicit per-client consent. Dynamic Client Registration is not a security control by itself.
5. Require confirmation for consequential writes where the client and plugin support it.
6. Verify logs record identity, client or token identifier, granted scope, tool, target object, result, and denial reason without leaking secrets or personal data. Check retention, administrator access controls, export, and tamper resistance.
7. Confirm that every MCP request revalidates authorization and that a session ID never acts as authentication.
8. Test token revocation, refresh-token reuse, expired credentials, authorization-code replay, redirect-URI mismatch, underprivileged object access, and firewall behavior. Verify `Cache-Control: no-store` on discovery, authorization, token, and authenticated MCP responses.
9. Keep WordPress revisions, WooCommerce operational safeguards, and independent backups. A plugin's change log is not a backup.
10. Run destructive workflow tests on staging with representative plugins and data.

Avoid any setup that treats "OAuth supported" or "application password used" as the end of the security review. An authenticated agent can still be over-privileged, tricked, wrong, or connected to the wrong site.

Treat posts, comments, form submissions, product descriptions, fetched URLs, plugin metadata, and tool results as untrusted input. Authentication and scopes limit the blast radius of indirect prompt injection; they do not prevent it.

## Elementor, Gutenberg, and WooCommerce need explicit coverage

Generic post CRUD does not equal page-builder support.

Gutenberg content can contain nested blocks, block attributes, reusable patterns, templates, and global styles. Elementor stores structured page data outside a simple rendered post body. WooCommerce adds products, variations, inventory, customers, orders, refunds, taxes, shipping, coupons, and side effects that do not behave like blog posts.

Before adoption, run one representative staging test for every WordPress surface you intend to expose:

1. Retrieve an existing object and confirm that the tool returns native structure, not only rendered HTML.
2. Make a draft-only change to nested Gutenberg blocks, Elementor data, or a WooCommerce object.
3. Reload the object and inspect the saved value instead of trusting the tool response.
4. Review the public page for serialization, layout, metadata, and cache regressions.
5. Attempt the same write with an underprivileged user and confirm that WordPress rejects it.
6. Trigger the documented undo or rollback path, then inspect related emails, webhooks, stock, caches, and external systems.

Royal MCP and StifLi document dedicated Elementor operations. Easy MCP AI documents Gutenberg, templates, global styles, and broad WooCommerce tools. AI Engine documents Gutenberg tools in its free Core WordPress group, while WooCommerce management is listed among its Pro MCP tools. The official Adapter supports whatever carefully designed Abilities you or another plugin registers. None of those facts proves compatibility with your exact stack.

## When you need visual editing rather than MCP

Frontman is not an MCP server and does not connect arbitrary external clients to WordPress. [Frontman for WordPress](/wordpress/) is an alternative for administrators who want to request changes to posts, pages, Gutenberg blocks, Elementor content, menus, templates, widgets, allowlisted settings, media, and WooCommerce data beside a live preview.

Choose an MCP option when the workflow must start in Claude, ChatGPT, Cursor, or another external client. Choose Frontman when the workflow is: open the page, request a change, inspect the live result, then approve or revise it without configuring an external MCP client. Frontman is early-access software, requires an administrator account, sends relevant site content through its hosted agent service and configured model provider, and does not provide plugin-wide one-click rollback.

For the broader category decision, read [AI Agent Plugins for WordPress Compared](/blog/ai-agent-wordpress-plugin-comparison/). For current capabilities and data-flow boundaries, read [Install and Use Frontman for WordPress](/docs/integrations/wordpress/).

## Which WordPress MCP server should you choose?

Match your primary constraint to one starting point:

| If you need to...                                                                      | Start with...                                                                               |
| -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Install a focused MCP connector with practical WordPress integrations                  | [Royal MCP](https://wordpress.org/plugins/royal-mcp/)                                       |
| Build custom tools from WordPress Abilities                                            | [WordPress MCP Adapter](https://github.com/WordPress/mcp-adapter)                           |
| Combine content changes with SEO, Analytics, and Search Console data                   | [Easy MCP AI](https://wordpress.org/plugins/easy-mcp-ai/)                                   |
| Make documented rollback and tool profiles central to evaluation                       | [StifLi Flex MCP](https://wordpress.org/plugins/stifli-flex-mcp/)                           |
| Add MCP to an existing chatbot and WordPress AI framework                              | [AI Engine](https://wordpress.org/plugins/ai-engine/)                                       |
| Evaluate policy approval and enterprise governance controls                            | [miniOrange Secure MCP Server](https://wordpress.org/plugins/miniorange-secure-mcp-server/) |
| Operate several sites from a separate Node.js MCP process                              | [InstaWP MCP Server](https://github.com/InstaWP/mcp-wp)                                     |
| Edit supported WordPress surfaces beside a live preview without an external MCP client | [Frontman for WordPress](/wordpress/)                                                       |

Choose one candidate and test it on staging:

1. Connect with a dedicated low-privilege user.
2. Read an existing object.
3. Propose and approve a draft-only change.
4. Write, reload, and visually verify it.
5. Inspect the audit record.
6. Revoke access and test recovery.

Reject the candidate if an underprivileged write succeeds, a revoked token remains usable, logs omit the actor or target, rollback misses required side effects, or saved WordPress data differs from the tool response. Repeat the complete sequence after every major plugin or WordPress upgrade.

Need the workflow to start in Claude, ChatGPT, or Cursor? Follow the selected server's official setup guide.

Need visually reviewed WordPress editing without an external MCP client? Install [Frontman - Agentic AI Editor](https://wordpress.org/plugins/frontman-agentic-ai-editor/) on staging, then review its [current integration boundaries](/docs/integrations/wordpress/) before you connect a production site.
