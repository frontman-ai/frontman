---
"@frontman-ai/frontman-core": patch
---

Implement owner-only sandbox preview proxying for `{sandbox_id}.preview.*` hosts with shared app authentication, upstream target resolution from explicit `port_map.web_preview_host_port`, and HTTP/WebSocket proxy support for app traffic and Vite HMR. Add sandbox preview routing/config plumbing, runtime port-forward metadata persistence, and proxy/resolver/provider test coverage.
