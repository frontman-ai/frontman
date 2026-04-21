---
"@frontman-ai/frontman-core": patch
---

Refactor Swarm and Frontman streaming to consume ReqLLM chunk shapes end-to-end, removing the Swarm-specific chunk reconstruction layer. Preserve early tool-call announcements in channel streaming, keep deterministic malformed/dropped tool-argument handling, and align test mocks/fixtures with ReqLLM stream chunks.
