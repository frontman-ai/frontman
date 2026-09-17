---
"frontman": patch
"marketing": patch
"@frontman-ai/astro": patch
---

Add WebMCP tools for website support questions and agent feedback, with delivery to Discord through a dedicated server queue. Questions require user confirmation. Agent feedback does not. Submission results distinguish queued requests from unconfirmed delivery and do not promise replies.

Use the Astro integration's resolved server host for submissions. Reuse the existing agent-feedback Discord webhook without a separate enablement flag. Submissions are unavailable when that webhook is absent. Validate requests and disable Discord mentions. Use ten best-effort slots to limit unfinished submissions, and return HTTP 503 when all slots are occupied. This does not provide rate limiting. Prune terminal background jobs after seven days.
