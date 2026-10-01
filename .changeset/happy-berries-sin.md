---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
---

Keep connection configuration across failures and disposal. Expose ready connections only after ACP and relay initialization both succeed, and clean up partial connections when startup fails or is cancelled. Update checks now wait for both connections to be ready.

React consumers now use connection reducer state and dispatch directly instead of separate state fields and dispatch-only wrappers. Update checks derive the API base URL from the reducer configuration, as logout already does. Consumers outside the provider fail explicitly instead of receiving placeholder state and inactive actions. Accepted ACP updates now use application reducer actions and buffering effects instead of provider callbacks.

Session errors no longer clear healthy transport bindings or billing state. Failed conversations show a retry action. Outdated session callbacks, configuration, history, and task-list results cannot overwrite current state, including during overlapping requests for the same task.
