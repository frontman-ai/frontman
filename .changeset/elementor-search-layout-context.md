---
"@frontman-ai/frontman-wordpress": patch
---

Add opt-in stored layout context to Elementor site-wide text search. Return each matched element's parent, sibling position, nearest layout ancestor, and narrow stored style overrides without changing matches or candidate pagination. Reject ambiguous element IDs only when context is requested. Stored overrides and unresolved global references are not computed styles.
