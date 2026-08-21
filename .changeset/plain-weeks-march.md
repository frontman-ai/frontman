---
"@frontman-ai/client": minor
---

Render user messages optimistically as soon as they are submitted. Messages are inserted with a client-generated `optimistic-` id and swapped in place when the server echo arrives, so the text no longer disappears between pressing enter and the round trip completing.
