---
"@frontman-ai/frontman-client": patch
---

### Fixed
- **MCP `handleMessage` promise rejections are no longer silently swallowed** — async errors in the channel message handler are now caught, logged, and reported to Sentry instead of disappearing into an unhandled promise rejection that causes the agent to hang indefinitely.
