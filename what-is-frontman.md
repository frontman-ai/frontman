# What Frontman Is

Frontman is an open-source browser-based AI coding agent for frontend work.

It runs inside your app at `/frontman`, shows chat plus live preview, lets a user click a UI element, describe a change, then uses runtime context to edit real source files and verify hot reload.

Core idea: the agent sees the running app, not only source code.

It can inspect:

- Live DOM
- Computed CSS
- Component/source mappings
- Screenshots
- Console/server logs
- Routes
- Build errors
- Project files

## Integrations Included

- `@frontman-ai/nextjs`
- `@frontman-ai/astro`
- `@frontman-ai/vite`
- WordPress plugin: `libs/frontman-wordpress`
- Browser/client UI: `@frontman-ai/client`
- Protocol client: `@frontman-ai/frontman-client`
- Shared schemas: `@frontman-ai/frontman-protocol`
- Server: Elixir/Phoenix app in `apps/frontman_server`
- Agent runtime: `apps/swarm_ai`
- Chrome extension app in monorepo
- OpenClaw skill support
- LLM providers: Anthropic, OpenAI, OpenRouter; docs also mention Fireworks and NVIDIA model catalog support
- Auth/OAuth: Anthropic/OpenAI OAuth, WorkOS for GitHub/Google login
- Observability: OpenTelemetry for Next.js logs/spans, Sentry on server

WordPress tools include:

- Posts/pages
- Gutenberg blocks
- Elementor layouts
- Menus
- Templates/template parts
- Widgets
- Site options/settings
- Media
- Cache tools
- WooCommerce when active

## Framework Integration Model

All JS framework integrations follow same pattern: dev-server adapter wraps shared Frontman core.

They:

- Serve Frontman UI at `/frontman`
- Expose tool endpoints like `/frontman/tools` and `/frontman/tools/call`
- Allow file read/edit/search through local dev server
- Resolve selected DOM/source locations back to files
- Relay tool calls from server through browser to dev server
- Run development-only; production builds strip it out

## Next.js

Package: `@frontman-ai/nextjs`

Hooks through:

- `middleware.ts` for Next 15
- `proxy.ts` for Next 16+
- Optional `instrumentation.ts` for OpenTelemetry

Captures:

- Console logs
- Build output
- Uncaught exceptions
- Unhandled rejections
- HTTP requests
- API routes
- Render spans

Uses circular buffer on `globalThis` so logs survive Turbopack/Next isolated execution contexts.

## Astro

Package: `@frontman-ai/astro`

Hooks through Astro integration API:

- `astro:config:setup`
- `astro:server:setup`

Does:

- Registers dev toolbar app
- Injects source annotation capture script
- Uses Vite middleware
- Reads Astro source annotations like `data-astro-source-file`
- Supports static, SSR, hybrid Astro modes

## Vite

Package: `@frontman-ai/vite`

Hooks through Vite plugin:

- `configureServer`
- Connect middleware

Supports:

- React
- Vue
- Svelte/SvelteKit
- SolidJS
- Vanilla JS/TS
- Other Vite-compatible frameworks

Adapts Node `IncomingMessage`/`ServerResponse` to Web API `Request`/`Response`, including SSE stream piping.

## WordPress

Plugin runs inside WordPress.

It:

- Serves `/frontman`
- Uses WordPress cookie auth
- Loads hosted Frontman UI assets
- Handles tool calls server-side in PHP
- Exposes WordPress-native tools
- Can technically run in production, unlike JS framework integrations, but is marked experimental

## Protocols

Frontman uses several protocol layers.

## JSON-RPC 2.0

Base wire format for client/server messages.

Used over Phoenix WebSockets for:

- `acp:message`
- `mcp:message`

Malformed messages intentionally crash channels rather than silently fail.

## ACP: Agent Client Protocol

Conversation/session protocol.

Handles:

- Session creation/loading/deletion
- User prompts
- Assistant streaming
- Tool call display updates
- Plan updates
- Turn completion
- Model/config updates

Events include:

- `UserMessageChunk`
- `AssistantMessageStart`
- `ToolCallStart`
- `ToolInputChunk`
- `ToolCallEnd`
- `TurnComplete`
- `PlanEntry`

## MCP: Model Context Protocol

Tool protocol.

Frontman uses MCP concepts for:

- `initialize`
- `tools/list`
- `tools/call`
- Tool discovery
- Tool execution
- Browser-side tools
- Relay tools to dev server

Flow:

```text
Agent -> Frontman Server -> Browser MCP client -> Dev Server tool endpoint
Agent <- Frontman Server <- Browser MCP client <- Dev Server result
```

## Relay Protocol

Frontman-specific framework relay.

Used when browser forwards MCP tool call to local dev server.

Includes:

- `remoteTool`
- `toolsResponse`

Transport:

- HTTP request to dev-server endpoint
- SSE stream for tool results

## WebSocket

Browser client connects to Frontman server at `/socket`.

Used for:

- Streaming agent responses
- Tool call routing
- Tool results
- Session state
- Reconnection/history replay

## HTTP/SSE

Used between browser and local dev server framework integration.

Used for:

- Tool calls
- Streaming tool results
- Source resolution
- UI asset serving

## OpenTelemetry

Used mainly in Next.js integration.

Captures:

- Logs
- Spans
- HTTP/request/render timing

Frontman writes OTEL processors into its log buffer so agent can query server/runtime context.

## OAuth/Auth Protocols

Uses:

- OAuth for Anthropic/OpenAI account connection
- WorkOS OAuth for GitHub/Google login
- Signed JWT/socket token for cross-origin WebSocket auth
- Session cookie for same-origin auth

## Not WebMCP

Repo docs say Frontman is not WebMCP. Similar philosophy, different layer.

WebMCP exposes website actions as browser tools. Frontman exposes dev/runtime/frontend-editing tools so an agent can map live UI back to source and edit code.
