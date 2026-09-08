---
"@frontman-ai/frontman-wordpress": minor
---

Add exact-text editing to `wp_update_custom_css` with `oldText`, `newText`, and optional `replaceAll`. Agents can change small sections without sending the complete stylesheet. Existing full-replacement calls remain supported.

Add persisted-source reads, scope checks, best-effort conflict detection, and compact edit receipts. Reject edits to preprocessor-backed CSS.
