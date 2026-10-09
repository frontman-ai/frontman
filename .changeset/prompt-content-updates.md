---
"@frontman-ai/client": patch
---

Move prompt content-presence state into the reducer so typing only updates React when the editor changes between empty and non-empty. Remove duplicate clear notifications and prevent editability changes from emitting text updates.
