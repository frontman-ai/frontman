---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
---

Reject prompts that exceed the 8 MB WebSocket message limit without clearing the draft. Count text, images, annotations, metadata, and transport overhead together. Reject PDF and document attachments with instructions to paste text or use images; keep historical attachments and explicitly state that their contents were not read.

The transport budget is 8,000,000 UTF-8 JSON bytes. Draft validation reserves 4 KiB for UUID session IDs/topics, numeric request IDs, and JSON-RPC/Phoenix framing (under 256 bytes). The final check includes the actual topic and reserves 16 digits for each Phoenix reference. Bandit enforces 8,000,014 bytes per frame, including its maximum 14-byte header, and 8,000,000 bytes per fragmented message. The fragmented limit is configured on Bandit because Phoenix socket options do not accept it.
