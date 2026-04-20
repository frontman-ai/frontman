---
"@frontman-ai/frontman-core": patch
"@frontman-ai/client": patch
"@frontman-ai/astro": patch
"@frontman-ai/nextjs": patch
---

Centralize path normalization and filename pattern matching to shared helpers across core and framework packages. This removes duplicate `toForwardSlashes` logic from client/Next.js/Astro path conversion and moves search/file matching logic into reusable frontman-core utilities, while adding focused regression tests for mixed separators and wildcard/case-insensitive pattern matching.
