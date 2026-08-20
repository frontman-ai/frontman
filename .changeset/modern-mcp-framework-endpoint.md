---
"@frontman-ai/frontman-core": major
"@frontman-ai/nextjs": major
"@frontman-ai/astro": major
"@frontman-ai/vite": major
---

Replace the private Relay routes, wrappers, schemas, and custom SSE output with explicitly secured MCP Streamable HTTP endpoints for Next.js, Astro, and Vite. The endpoints include strict Origin validation, preflight and method policy, synchronous JSON dispatch, authorization-principal rate limits, bounded registry admission and output-schema validation for successful and error results, server identity on every result, cancellation-aware tool execution, a ten-minute absolute request deadline, generated Next.js routing with bearer authentication, shared real-process transport verification including WordPress Playground, exact Astro routing across every trailing-slash mode, MCP trace suppression, and a separate fail-closed Origin policy for source-location resolution.
