---
"@frontman-ai/frontman-wordpress": minor
---

Add exact-fragment editing to `wp_update_post` for user-authorized changes to draft, freeform HTML, and block HTML posts. Readbacks include a content SHA256 hash. Edit mode requires a fresh hash and one unique exact-text anchor, preserves surrounding bytes and omitted fields, and reuses existing save permissions and verification. Conflict detection is best-effort, not atomic.
