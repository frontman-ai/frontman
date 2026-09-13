---
"@frontman-ai/client": patch
"@frontman-ai/frontman-protocol": patch
"@frontman-ai/frontman-preview-bridge": patch
---

Collect prompt page context through Reworker instead of reading the iframe from the parent. Avoid cross-origin window inspection during bridge setup, and reject delayed prompts when their original session is no longer active.
