---
"@frontman-ai/frontman-wordpress": patch
---

Add opt-in installation paths to `wp_get_site_info` for read-only location checks. Keep paths out of default results and preserve administrator-only access. Report the configured WordPress root and its resolved path without exposing general filesystem tools.
