---
"@frontman/bindings": patch
"@frontman-ai/frontman-core": patch
"@frontman-ai/nextjs": patch
"@frontman-ai/frontman-client": patch
"@frontman-ai/astro": patch
"@frontman-ai/frontman-protocol": patch
---

Enforce pure bindings architecture: extract all business logic from `@frontman/bindings` to domain packages, delete dead code, rename Sentry modules, and fix circular dependency in frontman-protocol.
