# Frontman Architecture

## System Purpose

Frontman is a browser-based AI agent that executes LLM-driven tool calls against a live DOM. Users send natural language prompts; the server orchestrates LLM calls; the client executes browser tools (screenshots, DOM reads, clicks, navigation) and returns results to the server for the next agent loop iteration.

---

## Monorepo Structure

**18 Yarn workspaces.** ReScript 12, Elixir 1.19.3, Yarn 4.10.3, Node 24.

```
apps/
  frontman_server/      Elixir/Phoenix backend
  swarm_ai/             Agentic loop runtime (Hex package)
  marketing/            Astro 5.17 static site
  chrome-extension/     Chrome extension

libs/
  client/               React UI components (ReScript) — @frontman-ai/client
  frontman-client/      ACP/Relay/MCP protocol implementation
  frontman-protocol/    Protocol type definitions + Sury schemas
  frontman-core/        Core utilities
  react-statestore/     State management (useSyncExternalStore)
  logs/                 Functor-based logger
  bindings/             ReScript JS bindings
  frontman-astro/       Astro integration (npm)
  frontman-nextjs/      Next.js integration (npm)
  frontman-vite/        Vite integration (npm)
  frontman-standalone/  Standalone bundle
  experimental-rescript-webapi/  WebAPI bindings (subtree)

test/e2e/              Playwright E2E tests (fixtures: nextjs, astro, vite, vue-vite)
infra/local/           Caddy, dnsmasq config
infra/production/      Deploy scripts (Hetzner)
bin/                   Worktree management scripts
```

---

## Agent Execution Loop

```
Client                          Server                          LLM Provider
  │                               │                               │
  │──── prompt (ACP/WS) ────────►│                               │
  │                               │──── API call ────────────────►│
  │                               │◄──── response + tool_calls ───│
  │                               │                               │
  │                               │── backend tool? ──► execute   │
  │                               │   (todo list)      server-side│
  │                               │                               │
  │◄── MCP tool call (WS) ───────│── MCP tool? ──► Registry.wait │
  │                               │                               │
  │── execute browser tool        │                               │
  │   (screenshot/DOM/click)      │                               │
  │                               │                               │
  │──── tool result (WS) ────────►│── Registry.notify             │
  │                               │──── feed result to LLM ──────►│
  │                               │◄──── next response ───────────│
  │                               │                               │
  │                               │   ... loop until turn_complete│
  │                               │                               │
  │◄── interactions (WS) ────────│── persist to DB, then PubSub  │
```

**Sequence:**
1. `TaskChannel.handle_in("acp:message")` receives prompt
2. `Providers.prepare_api_key` resolves key (user → env → server, with quota check)
3. `Execution.build_agent` assembles prompt template, model config, tool list
4. `Execution.submit_to_runtime` submits to `SwarmAi.Runtime`
5. Runtime calls LLM via `ReqLLM` (custom Req wrapper), receives response
6. `ToolExecutor.make_executor` routes tool calls:
   - Backend tools → `ToolExecution.Sync`: executed in Runtime process (todo list, web_fetch)
   - MCP tools → `ToolExecution.Await`: registered in `ToolCallRegistry`, published to client via channel, executor blocks until Registry receives result
7. `SwarmDispatcher` persists each interaction to PostgreSQL, then broadcasts via PubSub
8. Channel pushes events to client for UI rendering
9. Loop repeats until LLM returns `turn_complete`

**Persist-then-broadcast:** All agent events are persisted to PostgreSQL *before* being broadcast via PubSub. If the client disconnects, no data is lost. On reconnect, full history is loaded from the database and deserialized via `Interaction.to_llm_messages/1`.

### Tool Relay (File Operations)

File tools (read_file, write_file, edit_file, grep, etc.) don't run on the Frontman server — they relay through the browser to the user's dev server:

```
Agent (server) ──MCP tool call──► Browser (client) ──HTTP──► Dev Server (local)
                                                               │
Agent (server) ◄──MCP tool result── Browser (client) ◄────────┘
```

The Frontman server has no direct filesystem access. All file operations execute on the machine running the dev server, routed through the browser's MCP client. This means:
- File tools require an active browser connection
- The dev server framework integration (Next.js/Astro/Vite middleware) handles the actual filesystem I/O
- Tools are registered in `libs/frontman-core/src/FrontmanCore__ToolRegistry.res`

---

## Server (Elixir/Phoenix)

### Supervision Tree

```
Application
├── Repo (PostgreSQL connection pool)
├── Vault (Cloak encryption)
├── SwarmAi.Runtime (named: FrontmanServer.AgentRuntime)
├── Registry (FrontmanServer.ToolCallRegistry)
├── Oban (background jobs)
├── Task.Supervisor
├── Endpoint (HTTP/WebSocket)
└── Discord notifier (prod-only, PG LISTEN/NOTIFY)
```

### Contexts

| Context | Modules | Responsibility |
|---------|---------|---------------|
| Accounts | User, UserToken, UserIdentity | Registration, session tokens, OAuth (WorkOS for GitHub/Google), email verification |
| Tasks | Task, Interaction | CRUD for conversation sessions, interaction storage (JSONB), PubSub topics |
| Execution | Execution, SwarmDispatcher, ToolExecutor | Agent run orchestration, prompt building, tool routing, result notification |
| Providers | ApiKey, OauthToken, UserKeyUsage, ModelCatalog | Key resolution hierarchy, usage quota tracking, OAuth token management, model catalog |
| Tools | Backend, ToolExecutor | Tool registry, backend implementations (TodoList/Add/Update/Remove), MCP aggregation |
| Organizations | Organization, Membership | Team workspaces, membership roles |

### Database Schema

| Table | Key Fields |
|-------|-----------|
| users | id, email, name, hashed_password, confirmed_at, last_signed_in_at |
| users_tokens | user_id, token (binary), context |
| tasks | id (binary_id, client-provided), short_desc, framework, user_id |
| interactions | id, task_id, type (string), data (JSONB), sequence (bigint) |
| api_keys | user_id, provider, key (encrypted binary via Cloak) |
| user_identities | user_id, provider, provider_uid |
| oauth_tokens | user_id, provider, access_token (encrypted), metadata |
| user_key_usages | user_id, provider, usage_count |
| organizations | id, name, slug, owner_id |
| memberships | user_id, organization_id, role |

Encrypted fields: `api_keys.key`, `oauth_tokens.access_token` — use `FrontmanServer.Encrypted.Binary` (Cloak vault).

### Interaction Domain Model

Interactions are typed domain events persisted as JSONB:

| Type | Purpose |
|------|---------|
| UserMessage | User sends text/images/annotations |
| AgentResponse | LLM produced text chunks |
| AgentSpawned | Agent process started |
| AgentCompleted | Agent turn succeeded |
| AgentError | LLM/tool/runtime error |
| AgentPaused | Tool timeout (on_timeout: :pause_agent) |
| AgentRetry | User retried failed turn |
| ToolCall | Tool invoked by LLM |
| ToolResult | Tool returned result |
| DiscoveredProjectRule | Agent found project rules |
| DiscoveredProjectStructure | Agent found project structure |

No incremental mutations — full domain objects persisted atomically.

**Monotonic sequence generation:** `unix_seconds * 1_000_000 + (monotonic_counter mod 1_000_000)`. Guarantees deterministic ordering without DB round-trips. Cross-restart monotonicity from timestamp; BEAM-unique tiebreaker from `System.unique_integer/1`. A unique index on `(task_id, data->>'id') WHERE type = 'tool_result'` deduplicates tool results.

### Tool Execution

MCP tool metadata includes:
- `executionMode` — `"interactive"` (shorter timeout, pauses agent on timeout) vs default (longer timeout)
- `timeout_ms`, `on_timeout` — `:error` (fail the tool call) vs `:pause_agent` (pause and wait for user)

`MCPInitializer` negotiates available tools during session init via `tools/list` handshake.

### WebSocket Channels

- **UserSocket** — Two auth paths: session cookie (same-origin) or signed token (cross-origin, 2-week validity)
- **TasksChannel** (`"tasks"`) — Session listing/creation/deletion, config option broadcasts, ACP protocol init
- **TaskChannel** (`"task:*"`) — Per-task: ACP prompts, MCP tool call/response routing, streaming agent responses, history loading

Wire format: JSON-RPC 2.0. Event types: `"acp:message"`, `"mcp:message"`. No catch-all handlers — malformed messages crash the channel.

### API Key Resolution

Priority order:
1. User API key (encrypted in DB)
2. Environment API key (passed from client)
3. Server API key (from config, free tier — 10-run quota per user tracked in `user_key_usages`)

### Model Catalog

Providers: OpenRouter (full + free tier), Anthropic (direct), OpenAI (direct).
Defaults: Gemini 3 Flash (OpenRouter free), Claude Sonnet 4.5 (Anthropic), GPT-5.4 (OpenAI).
Tier logic: full tier = user has own key; free tier = server key with limited model selection.

### Routes

- `/health` — Liveness + readiness
- `/api/user/*` — User settings, API key management
- `/api/oauth/*` — OAuth flows (Anthropic, ChatGPT device auth)
- `/api/socket-token` — Signed JWT for WebSocket auth
- `/auth/*` — WorkOS OAuth callbacks (GitHub, Google)
- `/users/*` — Session management, settings
- `/socket` — WebSocket endpoint (UserSocket)

### Observability

- OpenTelemetry: SwarmAi events → OTEL spans
- Sentry: crashed process exceptions, PlugCapture
- Structured logging with metadata: request_id, task_id, pid, reason

---

## Client (ReScript/React)

### State Management

Built on `libs/react-statestore` which uses React 18's `useSyncExternalStore`.

Reducer signature: `(state, action) → (state, array<effect>)`. Effects execute after dispatch.

**State shape:**
```
state = {
  tasks: Dict<taskId, Task.t>
  currentTask: New(...) | Selected(taskId)
  acpSession: acpSession callbacks
  sessionInitialized: bool
  usageInfo: option<usageInfo>
  userProfile: option<userProfile>
  openrouterKeySettings / anthropicKeySettings: apiKeySettings
  anthropicOAuthStatus / chatgptOAuthStatus: OAuth state machines
  configOptions: option<array<sessionConfigOption>>
  selectedModelValue: option<sessionConfigValueId>
  sessionsLoadState: sessionsLoadState
}
```

Task sub-reducer (`Client__Task__Reducer`) handles per-conversation state. Tasks start as `New` (local-only); transition to `Loaded` on first server-side session creation.

Public API: `Client__State.useSelector`, `Client__State.Actions.*`, `Client__State.Selectors.*`.

### Connection Layer

```
Main.res
└── FrontmanProvider (React context)
    └── ConnectionReducer
        ├── ACP connection (handshake, session mgmt)
        ├── Relay (WebSocket transport)
        └── MCP Server (tool registration, call dispatch)
```

`FrontmanProvider` exposes: `sendPrompt`, `cancelPrompt`, `loadTask`, `deleteSession`, `connectionState`.

`TextDeltaBuffer` batches streaming text chunks, flushing every 100ms or on message boundaries.

### Component Tree

```
Client__App
└── Client__FrontmanProvider
    └── Client__Chatbox
        ├── Client__MessageContainer
        │   ├── Client__UserMessage
        │   └── Client__AssistantMessage
        ├── Client__ToolCallBlock / Client__ToolGroupBlock
        ├── Client__QuestionDrawer
        ├── Client__TodoListBlock
        ├── Client__PlanDisplay
        ├── Client__ThinkingIndicator
        ├── Client__PromptInput
        ├── Client__ErrorBanner
        └── Client__UpdateBanner
    └── Client__WebPreview
        ├── Client__WebPreview__Nav
        ├── Client__WebPreview__DeviceBar
        ├── Client__WebPreview__Body (iframe)
        ├── Client__WebPreview__AnnotationControls
        ├── Client__WebPreview__AnnotationMarkers
        ├── Client__WebPreview__AnnotationPopup
        └── Client__WebPreview__HoveredElement
```

File naming: `Client__ComponentName.res` (flat directory, double-underscore namespacing).

### Client-Side MCP Tools

Registered in `Client__ToolRegistry`:

| Tool | Function |
|------|----------|
| TakeScreenshot | Renders iframe to PNG |
| Navigate | Sets iframe URL |
| GetDom | Serializes DOM tree with selector paths |
| GetInteractiveElements | Finds buttons, inputs, links |
| InteractWithElement | Click, type, scroll, etc. |
| SearchText | Find text in DOM |
| SetDeviceMode | Responsive device simulation |
| Question | Blocks agent, asks user for input via UI drawer |

Question tool: creates a Promise that blocks the agent loop. Dispatches `QuestionReceived` to state with resolve/reject callbacks. User submits answers → `QuestionSubmitted` → calls `resolveOk` → Promise resolves → tool result returned to server.

### Core File Tools (frontman-core)

Registered in `FrontmanCore__ToolRegistry`, relayed through the browser to the dev server:

| Tool | Module | Function |
|------|--------|----------|
| ReadFile | `FrontmanCore__Tool__ReadFile` | Read file content with offset/limit |
| WriteFile | `FrontmanCore__Tool__WriteFile` | Write complete files (creates parent dirs) |
| EditFile | `FrontmanCore__Tool__EditFile` | Targeted edits with line-based pattern matching |
| ListFiles | `FrontmanCore__Tool__ListFiles` | Directory listing |
| SearchFiles | `FrontmanCore__Tool__SearchFiles` | Glob-based file search (uses `git ls-files`) |
| Grep | `FrontmanCore__Tool__Grep` | Content search (ripgrep, git grep fallback) |
| ListTree | `FrontmanCore__Tool__ListTree` | Tree structure via `git ls-files` |
| FileExists | `FrontmanCore__Tool__FileExists` | File existence check |
| LoadAgentInstructions | `FrontmanCore__Tool__LoadAgentInstructions` | Load project rules (AGENTS.md) |

---

## Protocol Stack

Three layers:

1. **JSON-RPC 2.0** — Wire format for all messages
2. **ACP (Agent Client Protocol)** — Session lifecycle (create/load/delete), prompt send/receive, config updates
3. **MCP (Model Context Protocol)** — Tool definitions, tool call routing (server → client → server)

Type definitions: `libs/frontman-protocol`. Serialization: Sury schemas with `@schema` annotation PPX.

Content block types: `TextContent`, `ImageContent`, `AudioContent`, `EmbeddedResource`.

Session update types: `UserMessageChunk`, `AssistantMessageStart`, `ToolCallStart`, `ToolInputChunk`, `ToolCallEnd`, `TurnComplete`, `PlanEntry`.

---

## Framework Integrations

Three published npm packages inject Frontman into dev servers:

- **@frontman-ai/astro** (`libs/frontman-astro`) — Astro integration hook + Vite middleware, dev toolbar app, serves Frontman UI at `/<basePath>/`, captures `data-astro-source-file` annotations, component props injection as HTML comments
- **@frontman-ai/nextjs** (`libs/frontman-nextjs`) — Middleware (Next.js 15) or proxy (Next.js 16+), serves Frontman UI at `/frontman`, OpenTelemetry instrumentation (tracks HTTP requests, route rendering, API execution), LogCapture (auto-patches console.log, process.stdout.write, error handlers — circular buffer of 1024 entries via `globalThis`)
- **@frontman-ai/vite** (`libs/frontman-vite`) — Vite middleware plugin, auto-detects framework from vite.config (React, Vue, Svelte), adapts Web API to Vite's Node.js request/response

All three packages inject the Frontman client UI into dev servers, establish WebSocket connection to the Frontman backend, and handle MCP tool relay (routing file operations from the agent through the browser to the local filesystem).

---

## Marketing Site

Astro 5.17 at `apps/marketing/`. 94 components. Deployed to Cloudflare Pages.

Content: 16 blog posts, 10 competitor comparison pages (`/vs/`), 3 integration guides (`/integrations/`), glossary, lighthouse audits. Blog cover images generated server-side via `satori` + `sharp`.

Uses `@frontman-ai/astro` integration for live product demo in dev mode.

---

## Infrastructure

### Local Development

| Component | Technology |
|-----------|-----------|
| Process management | mprocs (7 concurrent processes) |
| Containers | Podman pods (per-worktree) |
| Reverse proxy | Caddy (`{hash}.{service}.frontman.local`) |
| DNS | dnsmasq (`*.frontman.local → 127.0.0.1`) |
| Secrets | 1Password CLI (`op run --env-file`) |
| Runtime versions | mise (Node 24.4.1, Erlang 28.1.1, Elixir 1.19.3) |

### Worktree System

Each feature branch gets:
- Git worktree at `.worktrees/<branch>/`
- Podman pod with PostgreSQL 16 container + dev container
- Deterministic port range derived from 4-char branch name hash
- Caddy routing: `{hash}.{service}.frontman.local → localhost:{port}`
- Isolated `.claude/` directory for separate Claude Code context

Management: `make wt` (dashboard), `make wt-new`, `make wt-dev`, `make wt-stop`, `make wt-start`, `make wt-sh`, `make wt-rm`, `make wt-gc`.

### CI/CD

GitHub Actions workflows:

| Workflow | Trigger | Function |
|----------|---------|----------|
| ci.yml | PR/push | ReScript build, 8 test jobs, lint (Biome + Credo), Dialyzer, protocol check, dead code detection |
| deploy.yml | push to main | Server: rsync to Hetzner → native build → blue-green deploy. Client: Vite bundle → Cloudflare Pages |
| deploy-marketing.yml | changes to marketing/astro | Astro build → Cloudflare Pages |
| e2e.yml | PR/push | Playwright tests across 4 framework fixtures |
| changelog-check.yml | PR | Enforces changeset presence (bypass: `skip-changelog` label) |
| release-pr.yml | manual (`make release`) | Runs `yarn changeset version`, creates release branch + PR |
| release-tag.yml | release PR merge | Creates git tag + GitHub Release |

Coverage gates: 70% for JS packages, 75% for Elixir server.

### Production

- Server: Hetzner bare metal, Ubuntu 24.04, blue-green deployment via `infra/production/deploy.sh`
- Client + Marketing: Cloudflare Pages (static)

---

## Licensing

- Client libraries & framework integrations (`libs/`) — Apache License 2.0
- Server (`apps/frontman_server/`) — GNU Affero General Public License v3

### Release Process

1. `yarn changeset` creates `.changeset/*.md` fragment
2. Fragments accumulate on main
3. `make release` triggers workflow → `yarn changeset version` → release PR
4. PR merge → auto git tag + GitHub Release
