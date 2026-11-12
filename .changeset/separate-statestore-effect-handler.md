---
"@frontman-ai/react-statestore": major
"@frontman-ai/client": patch
---

Require an explicit `~handleEffect` argument when creating a store or using the reducer hook. The reducer interface no longer requires a handler member.

Move selected model persistence and task load failure logging from client reducers into their effect handlers.

Pass task, message, attachment, annotation, and error identities and timestamps into reducer transitions explicitly.
