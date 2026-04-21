---
title: Troubleshooting
description: Fix common Frontman issues — UI not loading, agent timeouts, tool failures, WebSocket connection problems, and more.
---

# Frontman Troubleshooting Guide

This guide helps you diagnose and fix common Frontman issues quickly: Frontman not loading, agent timeouts, tool call failures, WebSocket disconnects, and code edits that do not apply.

If you are looking for setup docs, start with [Reference](/docs/reference/). You can also check [Compatibility](/docs/reference/compatibility/), [Configuration](/docs/reference/configuration/), [Environment Variables](/docs/reference/env-vars/), [Models](/docs/reference/models/), and [Architecture](/docs/reference/architecture/).

---

## Quick triage checklist (do this first)

When Frontman is not working, these checks resolve most issues:

1. Confirm your app dev server is running and reachable in the preview.
2. Hard refresh the browser tab (`Cmd/Ctrl + Shift + R`).
3. Confirm Frontman is connected (no persistent socket/disconnected state).
4. Verify API key/model access if the run fails before output.
5. Retry the prompt once after reconnect (to clear stale pending tool calls).
6. If file tools fail, confirm your framework integration is installed and active in dev mode.
7. Capture logs before restarting services (see [What to include in a bug report](#what-to-include-in-a-bug-report)).

---

## Frontman UI not loading

### Symptoms
- `/frontman` (or your configured base path) is blank.
- You see a 404 for the Frontman route.
- The page loads but chat/preview never initialize.

### Likely causes
- Framework integration is not installed or not enabled in dev mode.
- Wrong base path configuration.
- Dev server is running, but Frontman middleware did not mount.

### Fix
1. Verify integration setup:
   - Astro: `@frontman-ai/astro` (see [Astro integration docs](/docs/integrations/astro/))
   - Next.js: `@frontman-ai/nextjs` (see [Next.js integration docs](/docs/integrations/nextjs/))
   - Vite: `@frontman-ai/vite` (see [Vite integration docs](/docs/integrations/vite/))
2. Restart the dev server after config changes.
3. Confirm the expected Frontman route/path in your integration config.
4. Check browser devtools network tab for missing Frontman assets.

---

## WebSocket disconnected or reconnect loop

### Symptoms
- “Disconnected” status in chat.
- Prompt send fails or hangs.
- Reconnect spinner loops continuously.

### Likely causes
- Expired/invalid auth token or session.
- Backend restart or network interruption.
- Cross-origin/proxy misconfiguration in local setup.

### Fix
1. Refresh the page and re-authenticate if prompted.
2. Restart Frontman backend and your dev server.
3. If using a local reverse proxy/worktree hostnames, confirm routing is still valid (see [Self-hosting](/docs/reference/self-hosting/) for deployment and networking context).
4. Retry with a new prompt after reconnect (old in-flight tool calls may have failed).

---

## Agent stuck, slow, or timing out

### Symptoms
- Long “thinking” state with no text/tool output.
- Run fails with timeout.
- Agent appears paused indefinitely.

### Likely causes
- LLM provider latency/outage.
- Tool call waiting on a client-side result.
- Interactive question tool waiting for user input.

### Fix
1. Wait 15–30 seconds and check if a tool call appears in chat.
2. If a question drawer is open, answer it (the run is intentionally paused).
3. Cancel and retry once.
4. Switch to a different model/provider if available.
5. Check provider/key/quota status (see [API key, model, or quota errors](#api-key-model-or-quota-errors)).

---

## Tool call failed (screenshot, DOM, click, file tools)

### Symptoms
- Tool block shows error.
- Agent says it could not execute a tool.
- Repeated “tool call failed” messages.

### Likely causes
- Browser-side tool cannot access expected DOM state.
- Preview page changed (route/modal/auth state mismatch).
- File relay path/tool guardrails blocked the operation.
- Dev server integration endpoint unavailable.

### Fix
1. Ensure preview is on the expected route and state (logged in, modal open, etc.).
2. Re-run the request with explicit target details:
   - exact URL/route
   - exact button label
   - exact file path
3. For file operations, verify the file exists under your project root.
4. Retry after page refresh to clear stale iframe/tool state.

---

## “It said it edited code, but nothing changed”

### Symptoms
- Agent reports success, but file content is unchanged.
- UI did not update after an edit.

### Likely causes
- Edit pattern did not match current file content.
- Wrong file was targeted.
- Hot reload failed or preview is stale.

### Fix
1. Ask Frontman to `read_file` the exact path and verify current content first.
2. Request a narrower, explicit edit (specific function/block).
3. Manually refresh preview and verify dev server rebuild output.
4. If needed, ask Frontman to show the exact diff it applied.

---

## Wrong file changed or wrong element clicked

### Symptoms
- Agent modifies unrelated code.
- Agent interacts with a similarly named but wrong UI element.

### Likely causes
- Ambiguous instructions (“update this button” when multiple exist).
- Multiple matching selectors/text labels.
- Missing context about current route/component.

### Fix
1. Provide explicit scope:
   - full file path (`src/components/...`)
   - exact text/ARIA name of element
   - page route and section
2. Use disambiguating wording:
   - “the **Save** button in **Settings > Billing**, not profile settings”
3. Ask Frontman to inspect DOM or list interactive elements before acting.

---

## API key, model, or quota errors

### Symptoms
- Run fails immediately before agent output.
- Errors about invalid key, model unavailable, or quota exceeded.

### Likely causes
- Missing/invalid user key.
- Provider outage or model access restrictions.
- Free-tier/server-key usage limit reached.

### Fix
1. Re-check key configuration in user settings.
2. Try another model/provider to isolate provider-specific failures.
3. If using free tier, wait for quota reset or add your own API key.
4. Re-run after updating credentials.
5. Review [Models](/docs/reference/models/) and [Configuration](/docs/reference/configuration/) to confirm your selected provider/model is supported for your setup.

---

## Question drawer appears and run looks frozen

### Symptoms
- Agent asks a multiple-choice/freeform question and does not continue.
- No new output appears until user action.

### Expected behavior
This is normal for interactive tool calls. The agent is waiting on your response.

### Fix
1. Open/answer the question drawer.
2. Submit a clear answer to resume the run.
3. If drawer is stuck visually, refresh and retry the prompt.

---

## Changes made but preview still old

### Symptoms
- Files updated on disk, but iframe still shows old UI.

### Likely causes
- Dev server HMR failed silently.
- Cached route or stale iframe state.
- Build error blocked rebuild.

### Fix
1. Check dev server terminal output for compile/runtime errors.
2. Hard refresh the browser tab.
3. Navigate preview away and back to force full render.
4. Restart dev server if HMR is consistently stale.

---

## What to include in a bug report

Include these details so issues can be reproduced quickly:

- Exact error text from the tool block or UI banner.
- Prompt used.
- Route/URL in preview.
- Expected behavior vs actual behavior.
- Framework and version (Astro/Next.js/Vite).
- Whether issue is intermittent or consistent.
- Relevant logs from:
  - browser console
  - dev server terminal
  - Frontman server logs

---

## Need more help?

If the steps above do not resolve your issue, use these support channels:

- [Discord](https://discord.gg/xk8uXJSvhC) — fastest path for troubleshooting with the community.
- [GitHub Issues](https://github.com/frontman-ai/frontman/issues) — report reproducible bugs and track fixes.

When opening a GitHub issue, include the details from [What to include in a bug report](#what-to-include-in-a-bug-report).

---

## FAQ

### Why does Frontman keep disconnecting?
Usually auth/session expiry, backend restarts, or local proxy/routing instability. Refresh, re-authenticate, then retry with a fresh prompt.

### Why do tool calls fail only on some pages?
Those pages often require specific runtime state (auth, modal open, scroll position, or feature flag). Recreate the exact page state before retrying.

### Why is Frontman editing the wrong place?
Ambiguous targets. Use explicit file paths, route names, and exact UI labels to disambiguate.

### Why does it stop and ask me a question?
The agent uses an interactive question tool when your input is required to proceed safely.

### Is this a model problem or a Frontman problem?
If the same prompt fails across multiple models, it is likely integration/tooling/state. If it fails only on one model/provider, it is likely provider/model behavior.
