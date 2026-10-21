---
"@frontman/frontman-server-assets": patch
---

Add a fresh scoped activation-candidate check with an inclusive UTC signup age bound, not send authorization. Backfill existing users with the migration timestamp so they do not receive activation emails; preserve recorded first-prompt timestamps.
