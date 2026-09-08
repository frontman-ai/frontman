---
"@frontman-ai/frontman-wordpress": patch
---

Store Elementor undo snapshots as Unicode-escaped JSON so emoji can be saved on legacy WordPress metadata charsets. Verify snapshot contents before saving edits, preserve existing rollback history, and report rejected writes separately from readback mismatches.
