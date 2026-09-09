---
"@frontman-ai/client": minor
"@frontman-ai/astro-browser": minor
"@frontman-ai/frontman-protocol": minor
---

Include the current preview URL in `get_dom` results. Add an Astro-only wrapper in `astro-browser` that reports fresh client-routing status from the inspected document and distinguishes unavailable previews from disabled routing. Share DOM input and output types through the protocol package and inject the inspector from the client. Keep the shared tool, output schema, and description free of Astro-specific metadata for other frameworks.
