---
"@frontman-ai/frontman-client": patch
---

Use Phoenix replies for ACP requests and settle pending requests when their channel closes. Remove duplicate request tracking and timers. Deploy the updated server before the client; existing clients already support Phoenix replies.
