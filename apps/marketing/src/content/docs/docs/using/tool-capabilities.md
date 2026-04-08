---
title: Tool Capabilities
description: Reference for every tool the Frontman agent can use — screenshots, DOM inspection, file editing, navigation, and more.
---

Frontman's agent has access to three categories of tools that run in different environments. Understanding what each tool does helps you write better prompts and predict what the agent will do.

| Category | Where it runs | Purpose |
|----------|---------------|---------|
| [**Browser tools**](#browser-tools) | In your browser, against the live preview | See the page, interact with elements, inspect the DOM |
| [**Framework tools**](#framework-tools) | On your machine, via the dev server plugin | Read/write files, discover routes, check build logs |
| [**Backend tools**](#backend-tools) | On the Frontman server | Fetch web pages, manage todo lists |

## Browser tools

Browser tools execute inside your browser tab, operating on the live preview iframe. They give the agent eyes and hands — it can see what's rendered, inspect the structure, and interact with elements.

### `take_screenshot`

Captures a screenshot of the current web preview page. Returns a base64-encoded JPEG image.

| Parameter | Type | Description |
|-----------|------|-------------|
| `selector` | string? | CSS selector to screenshot a specific element instead of the full page |
| `fullPage` | boolean? | Capture the entire scrollable page instead of just the visible viewport. Default: `false` |

The agent uses screenshots before and after edits to verify visual changes. This is the core of Frontman's perception-action loop — it's how the agent "sees" your running app.

### `execute_js`

Evaluates arbitrary JavaScript inside the web preview iframe and returns the result.

| Parameter | Type | Description |
|-----------|------|-------------|
| `expression` | string | JavaScript code to evaluate |
| `timeout` | number? | Maximum execution time in milliseconds. Default: 5000 |

Use cases include querying DOM properties, measuring layout, reading computed styles, and navigating pages. The expression runs via `new Function` in the iframe's window context. Promises are automatically awaited. DOM nodes, NodeLists, Maps, Sets, and circular references are serialized to readable JSON. Console output during execution is captured.

Output is capped at 30 KB.

### `get_dom`

Inspects a specific section of the DOM in the web preview.

| Parameter | Type | Description |
|-----------|------|-------------|
| `selector` | string | CSS selector or XPath expression targeting a DOM subtree |
| `mode` | string? | `"simplified"` (default) or `"full"` |
| `maxDepth` | number? | Maximum tree depth in simplified mode. Default: 5 |
| `maxNodes` | number? | Maximum element nodes to include. Default: 200 |
| `pierceShadowDom` | boolean? | Traverse into shadow DOM roots. Default: `false` |

**Simplified mode** returns a pruned indented representation with tag names, key attributes (id, class, role, aria-*, href, src), framework component names, and short text snippets. Script, style, and SVG elements are stripped. Capped at 200 nodes.

**Full mode** returns raw `outerHTML`. Capped at 15 KB. Use only when you need exact markup for a small, specific component.

If a subtree is too large, the tool rejects the request and returns a list of the element's direct children so the agent can pick a narrower target. This prevents wasting context window on huge DOM dumps.

### `get_interactive_elements`

Discovers clickable and interactive elements on the current page.

| Parameter | Type | Description |
|-----------|------|-------------|
| `role` | string? | Filter by ARIA role (e.g. `"button"`, `"link"`) |
| `name` | string? | Filter by accessible name substring (case-insensitive) |

Returns elements with their ARIA roles, accessible names, CSS selectors, detection method, and visible text. Detection methods include:

- **semantic** — elements with interactive ARIA roles (button, link, checkbox, etc.)
- **cursor_pointer** — elements styled with `cursor:pointer` (catches JS onclick handlers)
- **tabindex** — elements with a `tabindex` attribute

Results are capped at 50 elements.

### `interact_with_element`

Performs actions on elements in the web preview.

| Parameter | Type | Description |
|-----------|------|-------------|
| `selector` | string? | CSS selector (preferred) |
| `role` | string? | ARIA role — must be used with `name` |
| `name` | string? | Accessible name — must be used with `role` |
| `text` | string? | Visible text content to match |
| `action` | string? | `"click"` (default), `"hover"`, or `"focus"` |
| `index` | number? | 0-based index when multiple elements match |

Supports three targeting strategies:
1. **CSS selector** — most precise, use selectors from `get_interactive_elements`
2. **Role + name** — ARIA-based targeting (e.g. role=`"button"`, name=`"Submit"`)
3. **Text** — matches the innermost element containing the text

### `search_text`

Searches for visible text on the current page, like Ctrl+F.

| Parameter | Type | Description |
|-----------|------|-------------|
| `query` | string | Text to search for (case-insensitive) |
| `selector` | string? | Scope search to a CSS selector or XPath subtree |
| `maxResults` | number? | Maximum results. Default: 25 |
| `contextChars` | number? | Characters of surrounding context. Default: 80 |

Returns matching elements with surrounding text context, CSS selectors, tags, and accessibility metadata. Matches are wrapped in `>>` and `<<` markers within the context text.

### `set_device_mode`

Controls the device emulation mode for responsive design testing.

| Parameter | Type | Description |
|-----------|------|-------------|
| `action` | string | `"set_preset"`, `"set_custom"`, `"set_responsive"`, `"set_orientation"`, `"get_current"`, or `"list_presets"` |
| `device` | string? | Device preset name (for `set_preset`) |
| `width` | number? | Viewport width in CSS pixels (for `set_custom`) |
| `height` | number? | Viewport height in CSS pixels (for `set_custom`) |
| `orientation` | string? | `"portrait"` or `"landscape"` (for `set_orientation`) |

**Available presets:** iPhone SE, iPhone 15 Pro, iPhone 15 Pro Max, Pixel 8, Samsung Galaxy S24, iPad Mini, iPad Air, iPad Pro 11", iPad Pro 12.9", Laptop, Laptop L, 4K.

### `question`

Pauses the agent loop and asks you a question via an interactive drawer.

| Parameter | Type | Description |
|-----------|------|-------------|
| `questions` | array | Array of question objects, each with a `question`, `header`, `options` array, and optional `multiple` flag |

The agent uses this when it needs clarification, wants to offer a choice between approaches, or needs approval for a destructive action. The agent loop literally pauses — no LLM calls happen until you respond.

See [The Question Flow](/docs/using/question-flow/) for more detail.

---

## Framework tools

Framework tools run on your machine via the Frontman dev server plugin. They give the agent access to your project's files, route structure, and build output. There's a shared set of **core tools** available in every framework, plus **framework-specific tools** that vary by integration.

### Core tools (all frameworks)

These tools are available in every Frontman integration — Astro, Next.js, and Vite.

#### `read_file`

Reads a file from your project's filesystem.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | Path to file — relative to source root or absolute |
| `offset` | number? | Line number to start from (0-indexed). Default: 0 |
| `limit` | number? | Maximum lines to read. Default: 500 |

Returns the file content along with total line count and whether more content exists. For large files, the agent is instructed to use `grep` first to find relevant sections, then `read_file` with a targeted offset.

:::tip
The agent tracks which files it has read. The `edit_file` and `write_file` tools will refuse to modify files that haven't been read first — this prevents blind edits.
:::

#### `write_file`

Writes content to a file. Creates parent directories if they don't exist.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | Path to file — relative to source root or absolute |
| `content` | string? | Text content to write |
| `image_ref` | string? | URI of a user-attached image to save to disk |
| `encoding` | string? | Set to `"base64"` for binary data |

Provide either `content` or `image_ref`, not both. If the file already exists, the agent must read it first — the tool rejects writes to existing files that haven't been read.

Prefer `write_file` over `edit_file` when rewriting most of a file.

#### `edit_file`

Edits a file by finding text and replacing it, with fuzzy matching.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | Path to file |
| `oldText` | string | Text to find and replace. Empty string creates a new file. |
| `newText` | string | Replacement text |
| `replaceAll` | boolean? | Replace all occurrences. Default: `false` |

The tool uses multiple matching strategies — exact, line-trimmed, whitespace-normalized, indentation-flexible — to handle common formatting differences. This means the agent doesn't need to get whitespace exactly right.

The file must have been read first via `read_file`.

:::note
Each framework enhances `edit_file` with **post-edit error detection**. After applying the edit, the tool waits 800ms for HMR to process the change, then checks dev server logs for compilation errors. If errors are found, they're appended to the result so the agent can fix them immediately.
:::

#### `list_files`

Lists the immediate contents of a single directory.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string? | Directory to list. Default: project root. If a file path is given, lists its parent directory. |

Returns entries with name, path, and file/directory type. Respects `.gitignore`.

#### `list_tree`

Returns a recursive directory tree of the project structure.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string? | Subdirectory to root the tree at. Default: project root |
| `depth` | number? | Maximum depth. Default: 3 |

Includes monorepo workspace detection — workspace roots are annotated with `[workspace: name]`. Skips noisy directories like `node_modules`, `.git`, `dist`, and `build`. Respects `.gitignore`.

This tool also runs automatically during initialization to give the agent an overview of the project.

#### `file_exists`

Checks if a file or directory exists.

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | string | Path to check |

Returns `true` or `false`.

#### `grep`

Searches file contents for text or regex patterns using ripgrep (with git grep and plain grep as fallbacks).

| Parameter | Type | Description |
|-----------|------|-------------|
| `pattern` | string | Text or regex to search for |
| `path` | string? | Directory or file to search in. Default: source root |
| `type` | string? | File type filter (e.g. `"js"`, `"ts"`, `"py"`) |
| `glob` | string? | Glob pattern (e.g. `"*.tsx"`, `"*.{ts,tsx}"`) |
| `case_insensitive` | boolean? | Default: `false` |
| `literal` | boolean? | Treat pattern as literal text, not regex. Default: `false` |
| `max_results` | number? | Maximum files to return. Default: 20 |

Returns matching lines grouped by file, with line numbers. Results are sorted by file modification time (newest first). Binary and hidden files are skipped.

#### `search_files`

Searches for files by name across the project.

| Parameter | Type | Description |
|-----------|------|-------------|
| `pattern` | string | Filename pattern (supports glob-like: `"*.test.ts"`, `"Button*"`) |
| `path` | string? | Directory to search in. Default: source root |
| `max_results` | number? | Maximum results. Default: 20 |

Uses ripgrep `--files` with a git ls-files fallback. Matches file names only, not directory names. Hidden files (dotfiles) are included.

#### `lighthouse`

Runs a full Google Lighthouse audit on a URL.

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | string | The URL to audit (e.g. `http://localhost:4321/`) |
| `preset` | string? | `"desktop"` (default) or `"mobile"` |

Returns scores (0–100) for performance, accessibility, best practices, and SEO, plus the top 3 worst issues per category. Each issue includes descriptions, CSS selectors, HTML snippets, and source locations when available.

Requires Chrome to be installed. Takes 15–30 seconds per run.

:::tip
Only the 3 worst issues per category are returned. After fixing those, re-run the audit to surface additional issues that were previously ranked lower.
:::

### Astro-specific tools

These tools are added when Frontman is running as an Astro integration.

#### `get_client_pages`

Lists all routes resolved by Astro's router.

Returns routes from Astro's `astro:routes:resolved` hook, including pages, API endpoints, redirects, content collection routes, and integration-injected routes. Each route includes its pattern, entrypoint, type, origin, params, and prerender status.

This goes beyond simple filesystem scanning — it captures routes that don't exist as files in `src/pages/`, like content collection pages and config-based redirects.

#### `get_logs`

Retrieves Astro dev server logs from a rotating 1024-entry buffer.

| Parameter | Type | Description |
|-----------|------|-------------|
| `pattern` | string? | Regex pattern to filter messages (case-insensitive) |
| `level` | string? | Filter by type: `"console"`, `"build"`, or `"error"` |
| `since` | string? | ISO 8601 timestamp — only return logs after this time |
| `tail` | number? | Limit to most recent N entries |

Captures console output, Astro build/HMR logs, and uncaught exceptions with stack traces.

#### `get_astro_audit`

*(Astro only, runs in browser)*

Reads accessibility and performance audit results from Astro's dev toolbar. Traverses the toolbar's shadow DOM to extract the ~26 checks that Astro runs automatically.

Each entry includes the rule code, category (`a11y` or `performance`), human-readable title/message/description, and information about the offending element (tag name, CSS selector, text snippet).

### Next.js-specific tools

These tools are added when Frontman is running as a Next.js integration.

#### `get_routes`

Lists Next.js routes from the `app/` or `pages/` directory.

Returns routes based on filesystem routing conventions, including dynamic segments. Works with both the App Router and Pages Router directory structures.

#### `get_logs`

Retrieves Next.js dev server logs from a rotating 1024-entry buffer.

Same interface as the [Astro `get_logs`](#get_logs), but captures webpack/turbopack compilation output instead of Astro-specific logs.

### Vite-specific tools

These tools are added when Frontman is running as a Vite plugin.

#### `get_logs`

Retrieves Vite dev server logs from a rotating 1024-entry buffer.

Same interface as the [Astro `get_logs`](#get_logs), but captures Vite build/HMR logs.

:::note
The Vite integration doesn't include a route discovery tool since Vite is framework-agnostic and doesn't enforce a routing convention. If you're using a Vite-based framework (e.g. Vue Router, React Router), the agent uses `list_tree` and `grep` to discover routes.
:::

---

## Backend tools

Backend tools run on the Frontman server. They handle operations that don't need access to your browser or filesystem.

### `web_fetch`

Fetches a web page and returns its content as markdown.

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | string | URL to fetch (must start with `http://` or `https://`) |
| `offset` | number? | Line number to start from. Default: 0 |
| `limit` | number? | Maximum lines to return (1–2000). Default: 500 |

HTML pages are automatically converted to markdown. Results are paginated by lines for large pages. Includes SSRF protection — requests to private/internal addresses (localhost, 10.x.x.x, 192.168.x.x, etc.) are blocked.

### `todo_write`

Writes the complete todo list for the current task. Every call replaces the entire list.

| Parameter | Type | Description |
|-----------|------|-------------|
| `todos` | array | Complete todo list. Each item has `content`, `active_form`, `status` (`"pending"`, `"in_progress"`, `"completed"`), and optional `priority` (`"high"`, `"medium"`, `"low"`) |

The agent uses this for tasks with 3+ distinct steps. The todo list appears in the chat UI so you can track progress. See [Plans & Todo Lists](/docs/using/plans-and-todos/) for more detail.

---

## Tool summary by framework

This table shows which tools are available for each framework integration.

| Tool | Astro | Next.js | Vite | Where |
|------|:-----:|:-------:|:----:|-------|
| `take_screenshot` | ✓ | ✓ | ✓ | Browser |
| `execute_js` | ✓ | ✓ | ✓ | Browser |
| `get_dom` | ✓ | ✓ | ✓ | Browser |
| `get_interactive_elements` | ✓ | ✓ | ✓ | Browser |
| `interact_with_element` | ✓ | ✓ | ✓ | Browser |
| `search_text` | ✓ | ✓ | ✓ | Browser |
| `set_device_mode` | ✓ | ✓ | ✓ | Browser |
| `question` | ✓ | ✓ | ✓ | Browser |
| `get_astro_audit` | ✓ | — | — | Browser |
| `read_file` | ✓ | ✓ | ✓ | Dev server |
| `write_file` | ✓ | ✓ | ✓ | Dev server |
| `edit_file` | ✓ | ✓ | ✓ | Dev server |
| `list_files` | ✓ | ✓ | ✓ | Dev server |
| `list_tree` | ✓ | ✓ | ✓ | Dev server |
| `file_exists` | ✓ | ✓ | ✓ | Dev server |
| `grep` | ✓ | ✓ | ✓ | Dev server |
| `search_files` | ✓ | ✓ | ✓ | Dev server |
| `lighthouse` | ✓ | ✓ | ✓ | Dev server |
| `get_client_pages` | ✓ | — | — | Dev server |
| `get_routes` | — | ✓ | — | Dev server |
| `get_logs` | ✓ | ✓ | ✓ | Dev server |
| `web_fetch` | ✓ | ✓ | ✓ | Backend |
| `todo_write` | ✓ | ✓ | ✓ | Backend |

---

## How tools affect your prompts

Understanding the tool system helps you write better prompts:

- **Be specific about what you see** — the agent takes screenshots, but pointing at a specific element with an [annotation](/docs/using/annotations/) is faster than describing it.
- **Reference files by path** — saying "edit `src/components/Header.astro`" is more efficient than "edit the header component", because the agent can skip the search step.
- **Ask for responsive checks** — the agent can switch device presets, so you can say "make this work on mobile too" and it'll test with `set_device_mode`.
- **Request Lighthouse audits** — if you care about performance or accessibility, ask the agent to run a Lighthouse audit after making changes.
- **Let it iterate** — the agent's strength is the screenshot → edit → verify loop. Complex visual changes may take several iterations, and that's normal.
