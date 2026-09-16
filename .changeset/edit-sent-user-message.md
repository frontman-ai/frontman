---
"@frontman-ai/client": minor
"@frontman-ai/frontman-client": patch
"@frontman-ai/frontman-protocol": patch
---

Add editing of any sent user message. The pencil on a message loads its text back into the composer; sending the edit forks the conversation at that point, so the agent answers the edited prompt with everything after it set aside. Annotations, images and page context from the original are carried over. Nothing is deleted — the abandoned branch stays on record — and editing is only available while the agent is idle.
