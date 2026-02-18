---
"@frontman-ai/astro": patch
"@frontman/bindings": patch
---

Fix Astro integration defaulting to dev host instead of production when FRONTMAN_HOST is not set, which broke production deployments. Also add stderr maxBuffer enforcement to spawnPromise to prevent unbounded memory growth from misbehaving child processes.
