---
"@frontman/frontman-astro": patch
"@frontman-ai/nextjs": patch
---

Fix missing `host` param in Astro config that caused the client to crash on boot. Both Astro and Next.js configs now assert at construction time that `clientUrl` contains the required `host` query param, using the URL API for proper query-string handling.
