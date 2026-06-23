# Frontman Summary

## What Frontman Is

Frontman is an open-source, browser-native AI coding agent for frontend work. It lets a user open a running app, click an element, describe a change, and have the agent edit real source files with hot reload. Core positioning: ship frontend changes from the browser, no code editor needed.

## Core Idea

Most AI coding tools start from files. Frontman starts from the rendered app. It sees the live DOM, computed CSS, component tree, screenshots, selected elements, routes, server logs, source maps, and build errors, then works backward to source code.

## Who It Serves

Frontend developers get richer visual and runtime context than terminal or IDE agents provide.

Designers, PMs, and QA can make copy, spacing, color, and layout refinements without opening an IDE, while still producing reviewable code diffs.

Teams reduce design-engineering handoff loops for pixel fixes and UI polish.

## How It Works

1. A framework adapter is installed into the app dev server.
2. The `/frontman` route serves the Frontman UI beside a live preview.
3. The browser client acts as an MCP server with tools for DOM inspection, screenshots, interactions, and source detection.
4. Dev-server middleware exposes tools for file read/write/search, logs, and source-map resolution.
5. The Phoenix server orchestrates LLM tasks, streams responses, and routes tool calls between backend and browser.

Key protocols: MCP, JSON-RPC, Phoenix channels, and SSE.

## Architecture

### Frontend / Client

`libs/client` is the ReScript + React UI. It includes the chat panel, web preview, settings, task state, and browser-side tools.

Browser tools include screenshot capture, DOM extraction, JavaScript execution, interactive element discovery, element interaction, and framework-specific source detection.

### Framework Adapters

`@frontman-ai/nextjs` installs middleware/proxy and OpenTelemetry instrumentation to capture logs, build errors, routes, and runtime context.

`@frontman-ai/vite` installs a Vite plugin that serves `/frontman`, exposes tool endpoints, and resolves source locations.

`@frontman-ai/astro` installs an Astro integration that uses dev toolbar/source annotations, serves the UI, and exposes tool routes.

### Core Tooling

`libs/frontman-core` provides shared dev-server tooling: tool registry, HTTP/SSE middleware, path validation, file read/write/list, grep, search, logs, Lighthouse, and path-recovery guardrails.

### Server

`apps/frontman_server` is the Phoenix server. It manages accounts, auth, providers, tasks, WebSocket channels, and agent execution.

It resolves provider auth, prepares backend and MCP tools, starts LLM turns, persists interactions, and routes tool calls. Backend tools execute server-side; MCP tools route to the browser client.

Supported model/provider surfaces include Anthropic, OpenAI, OpenRouter-style models, OAuth tokens, and API keys.

### Agent Engine

`apps/swarm_ai` is an Elixir functional AI agent execution framework. It uses a functional core / imperative shell architecture: a pure state machine produces effects, while the execution layer performs LLM and tool I/O.

## Supported Frameworks

Canonical framework support includes Next.js, Vite, Astro, and WordPress.

## Product Position

Frontman is not an IDE replacement. It is a visual frontend editing layer for existing codebases.

It complements Cursor, Copilot, Claude Code, and similar tools: use IDE agents for broad code work, use Frontman when rendered UI context matters.

## Licensing

Frontman uses a split license model:

- `libs/`: Apache 2.0
- `apps/frontman_server/`: AGPL-3.0

## One-Sentence Summary

Frontman is a browser-first AI frontend agent: framework middleware turns a local dev server into a rich MCP tool surface, the browser UI captures live visual context, Phoenix and SwarmAi orchestrate LLM edits against real source files, and hot reload shows changes immediately.
