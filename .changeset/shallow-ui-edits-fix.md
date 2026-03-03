---
"@frontman-ai/client": minor
"@frontman-ai/frontman-core": patch
---

Fix shallow UI edits by giving the agent visual context and structural awareness. Add component name detection (React/Vue/Astro) to `get_dom` output, add UI & Layout Changes guidance to the system prompt with before/after screenshot workflow, add large-file comprehension strategy to `read_file`, and require edit summaries with trade-off analysis. Includes a manual test fixture (`test/manual/vite-dashboard/`) with a 740-line component to reproduce the original issue.
