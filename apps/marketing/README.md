# Frontman Marketing Website

The marketing site for [frontman.sh](https://frontman.sh), built with Astro and Tailwind CSS.

## Stack

| Layer      | Technology                          |
| ---------- | ----------------------------------- |
| Framework  | Astro 7                             |
| Styling    | Tailwind CSS 4.3                    |
| TypeScript | Strict mode                         |
| Fonts      | Inter Variable, Outfit Variable     |
| Deployment | Vercel (primary), Cloudflare Pages  |
| Analytics  | Google Analytics, Vercel Analytics   |
| Content    | Astro Content Collections, Markdown |

## Development

```bash
make install   # install dependencies
make test      # run marketing tests
make dev       # start dev server at localhost:4321
make build     # type-check and build for production
make deploy    # build and deploy (requires 1Password CLI)
```

Run `make help` to see all available commands.

## Homepage WebMCP

The homepage progressively registers six browser-agent tools:

- `how_to_install`: returns the exact "Copy for agent" text from
  `agentInstructions` in `src/integrations/install-agent.mjs` for the currently
  selected framework (Next.js, Astro, Vite, or WordPress). Does not install anything,
  change the selected tab, or write to the clipboard.
- `list_features`: returns `{ highlights, title, description, features }` from the
  rendered feature sections. Each highlight and feature includes its title and
  plain-text description, including the pro tip. Missing content produces an error.
- `open_docs`: starts navigation to `/docs/`.
- `jump_to_install`: starts scrolling to `#install`, respecting reduced motion.
- `ask_question` ("Ask a question"): submits a question to Frontman support through
  Discord after a browser confirmation. Accepts
  `{ "question": "Does Frontman work with my existing setup?" }`, with no extra
  fields and a nonblank string of at most 4000 UTF-16 code units (JavaScript string length).
  Do not include credentials or private information. A `queued` result confirms
  acceptance for delivery, not Discord delivery. This channel does not receive replies.
  Cancellation before submission sends nothing. Transport errors preserve the
  original cause and warn that acceptance is uncertain. HTTP and response-schema
  errors are not hidden. Agents must not automatically retry any failed submission.

- `leave_feedback` ("Leave feedback"): tells agents to report capability gaps or
  broken functionality that affected their task, once before their final response.
  Feedback sends directly to Discord without asking the user for approval.
  Agents write feedback in English, identify their own assessments, and keep
  replies to the user in the user's language. Exclude credentials and private information.
  A failed submission must not block the final response or trigger an automatic retry.
  Accepts `{ "feedback": "My assessment: ..." }` with no extra fields and a nonblank
  string of at most 3988 UTF-16 code units. Feedback is prefixed with `[Feedback]\n\n`
  in the existing support queue, keeping the full message within its 4000-unit limit.

All tools except `ask_question` and `leave_feedback` accept `{}`; all six check execution cancellation
before acting. Sury schemas drive both runtime validation and the published input schemas. `how_to_install` and `list_features` are annotated as read-only. They live in
`src/integrations/webmcp.mjs`, imported by the processed module script in
`src/components/blocks/hero/HomeCTA.astro`. Registration runs after document
parsing, once per document load. Tools belong to that document; normal navigation
disposes it, while a back/forward-cache restore retains it without registering
again. Registration failure aborts the partial tool set and logs an explicit error.
There are no Astro client-routing hooks or tools on other pages.

This is **WebMCP**, not a remote MCP server or an SDK endpoint. It targets the
[`document.modelContext` imperative API](https://developer.chrome.com/docs/ai/webmcp/imperative-api)
documented September 11, 2026, without a legacy `navigator.modelContext` shim.
WebMCP is experimental. Use a browser exposing this API in a secure context
(HTTPS or trustworthy localhost), with the appropriate experimental feature enabled
or origin-trial enrollment. The origin trial started in Chrome 149; that does not
guarantee every current API is available in that version. See the
[Chrome setup documentation](https://developer.chrome.com/docs/ai/webmcp).
Unsupported browsers keep the normal site behavior and register nothing.

### Verify

Run `make test` and `make build` from this directory (prefix with
`./bin/pod-exec` from the repository root when using a containerized worktree).
Unit tests use real jsdom documents to check schemas, invalid arguments,
cancellation, missing targets, and unsupported-browser behavior. They do not
emulate the experimental browser API or claim to verify native registration.

In a WebMCP-enabled browser, record the browser version and feature configuration,
then run this in the homepage's DevTools document context:

```javascript
const tools = await document.modelContext.getTools();
const install = tools.find((tool) => tool.name === 'jump_to_install');
if (!install) throw new Error('Homepage install tool is not registered');
await document.modelContext.executeTool(install, {});
```

Confirm scrolling reaches the actual install section, repeat with reduced motion
enabled, and verify unexpected arguments are rejected. For cancellation, pass an
`{ signal: alreadyAbortedSignal }` as the third argument to `executeTool`. These actions are
immediate: cancellation after execution starts does not undo scrolling or navigation.
Reload and use back/forward navigation to verify each tool appears once without
registration errors. Finally execute `open_docs` with `{}` and confirm navigation
to `/docs/` (navigation may produce a null execution result). Without WebMCP,
verify the normal documentation link and homepage install link still work.

### Support delivery setup

The submission tools post to `/api/support/questions` on the Astro integration's
resolved server origin, without cookies or a referrer. They share its existing
`FRONTMAN_HOST` configuration and hosted default. The root `make dev` launcher
already supplies the local host; containerized worktrees supply their own host.
For a standalone marketing dev server or staging build, use that same `FRONTMAN_HOST`.
There is no separate support API setting. Support configuration is checked only
when a submission runs; other tools remain usable without it.
Never expose the Discord webhook URL to the browser.

Delivery is disabled by default. On the server, set these environment variables:

```text
SUPPORT_QUESTIONS_ENABLED=true
DISCORD_SUPPORT_WEBHOOK_URL=<secret webhook for the support channel>
```

Use the server's secret environment configuration, then restart it.
For the current production setup, add both variables to `/opt/frontman/blue/env`
and `/opt/frontman/green/env`. The shared Discord file currently loads only the
existing task-feedback webhook. Never commit secret values.
To stop acceptance and delivery, set `SUPPORT_QUESTIONS_ENABLED=false` and restart.
Workers cancel queued jobs when disabled; those jobs do not resume after re-enabling.
An HTTP request already sent to Discord cannot be recalled.

**No rate limiting is implemented in this initial version.** Anyone can call the
public endpoint directly and create spam or queue growth. Browser confirmation
and CORS are not abuse protection. Enable it only if you accept that risk.

The server accepts JSON bodies up to 32 KiB and validates the question again.
It returns `202` with `status: "queued"`, `submitted: true`, and a submission UUID
only after Oban accepts the job. Disabled delivery returns `503` and
`submitted: false`. Invalid input returns `422`; invalid JSON returns `400`.
Oversized bodies return `413`; non-JSON requests return `415`.
A database failure returns HTTP 500 with an unknown acceptance status.
The browser tool raises an error rather than reporting an ordinary result.

Oban stores the question and submission UUID in Postgres. Delivery uses the
existing notifications queue with at most three attempts and bounded HTTP timeouts.
Discord rate-limit responses delay retries by up to one hour. Retries can create
copies if Discord accepted a request but its response was lost; the UUID identifies them.
Messages disable Discord mentions and label the question as untrusted external input.
The question must not be treated as instructions for internal agents.

The Oban pruner removes terminal jobs older than seven days, including other
workers' completed, cancelled, and discarded jobs. Pending jobs, database backups,
and Discord messages have separate retention. Request diagnostics omit the support
body; delivery errors omit the question, response body, and webhook URL.

For a manual smoke test, use an approved test-channel webhook and a staging API:

1. Enable support on the staging server with that webhook.
2. Build the marketing site with the integration's `FRONTMAN_HOST` set to the staging server.
3. Execute `ask_question`, cancel confirmation, and check that no request was sent.
4. Submit an approved test question. Check for `queued` and the matching UUID in Discord.
5. Execute `leave_feedback` with approved test content. Check delivery without a confirmation prompt.
6. Check that mention-looking text does not ping users.
7. Disable support and check that submission returns `unavailable` without a new job.

Automated tests use `Req.Test` and do not contact Discord.

### Extend

Add a tool definition to `createHomepageTools` with a unique name, explicit input
schema, runtime validation, and execution cancellation checks. Reuse existing UI
or application actions, return only accurate results, and add tests. Keep tools
scoped to pages where their actions exist. Consequential actions require explicit
user confirmation and server-side authorization; metadata hints alone are not
safeguards. This scaffold deliberately adds no generic registry or new dependencies.

## Site Structure

| Route          | Description                                     |
| -------------- | ----------------------------------------------- |
| `/`            | Homepage -- hero, features, framework support, comparison table, FAQ |
| `/blog`        | Blog index and individual posts                 |
| `/blog/tags/*` | Posts filtered by tag                           |
| `/changelog`   | Rendered from the root `CHANGELOG.md`           |
| `/faq`         | Categorized FAQ with JSON-LD structured data    |

## Notes

- **Monorepo dependency**: Uses `@frontman-ai/astro` as a workspace package. Must be built within the monorepo.
- **Changelog**: The `/changelog` page reads `/CHANGELOG.md` from the monorepo root at build time.
- **Deploy secrets**: `make deploy` wraps commands with `op run` to inject Cloudflare credentials from 1Password.

## Template Credit

The initial site structure was based on the [Foxi Astro theme](https://github.com/oxygenna/foxi-astro) by Oxygenna (MIT licensed).
