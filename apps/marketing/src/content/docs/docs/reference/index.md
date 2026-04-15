---
title: Reference
description: Technical reference for Frontman — configuration options, environment variables, architecture internals, supported models, framework compatibility, self-hosting, and troubleshooting.
---

The reference section covers everything under the hood: how Frontman is structured, how to configure it, and what to do when something goes wrong. If you're looking for step-by-step workflows, head to [Using Frontman](/docs/using/how-the-agent-works/) instead.

## Configuration & environment

Frontman ships with sensible defaults, but most projects need at least a few tweaks. The **[Configuration Options](/docs/reference/configuration/)** page documents every option available across Astro, Next.js, Vite, and standalone setups — with types, defaults, and descriptions. For secrets and server-side settings, **[Environment Variables](/docs/reference/env-vars/)** lists every variable the client and server recognize.

## Architecture & internals

**[Architecture Overview](/docs/reference/architecture/)** walks through the agent loop end-to-end: how a prompt becomes a screenshot, how the server queries MCP tools, and how edits flow back to your dev server. Understanding this flow helps when you're debugging unexpected behavior or contributing to the codebase.

## Models & providers

Frontman connects to multiple AI providers — OpenRouter, Anthropic, OpenAI, Google, and xAI — each with different authentication methods and model catalogs. The **[Models & Providers](/docs/reference/models/)** page lists every supported model, its ID, and how to authenticate. If you're choosing between providers or configuring a bring-your-own-key setup, start there.

## Framework compatibility

Not sure if your runtime or framework version is supported? The **[Supported Frameworks](/docs/reference/compatibility/)** page has the compatibility matrix for Astro, Next.js, Vite, Node.js, and browser versions.

## Self-hosting

Most users don't need to self-host — the client libraries are open source and run entirely in your browser. But if you need data sovereignty, air-gapped deployments, or custom server modifications, the **[Self-Hosting](/docs/reference/self-hosting/)** guide covers architecture, requirements, and deployment options.

## Troubleshooting

When things break, check **[Troubleshooting](/docs/reference/troubleshooting/)** for fixes to common issues: the UI not loading, agent timeouts, tool failures, and WebSocket connection problems.
