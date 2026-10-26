---
"@frontman-ai/client": patch
"@frontman/bindings": patch
---

Handle cross-origin preview navigation without WindowProxy option errors. Reload and address-bar navigation now reset the iframe from parent state, and preview tools reject stale documents until a supported page loads.
