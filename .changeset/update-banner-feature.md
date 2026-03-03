---
"@frontman-ai/vite": minor
"@frontman-ai/nextjs": minor
"@frontman-ai/astro": minor
"@frontman-ai/client": minor
---

Show in-browser banner when a newer integration package is available. Integration packages now report their real version (instead of hardcoded "1.0.0"), the server proxies npm registry lookups with a 30-minute cache, and the client displays a dismissible amber banner with an "Update" button that prompts the LLM to perform the upgrade.
