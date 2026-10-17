---
"@frontman/frontman-server-assets": patch
---

Add nullable UTC-second first-message observation storage without a default, backfill, index, or writer. Registration input cannot set it. A missing timestamp does not establish observation coverage.

Deploy the migration before the new binary; old binaries can coexist with the added column. Retain the column and values on application rollback; do not use the schema down-migration for routine rollback.
