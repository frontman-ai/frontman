# Spec: OAuth Activation Instrumentation

Measure client-only activation transitions in Heap without treating browser analytics as authoritative backend state. PostgreSQL remains authoritative for OAuth completion, credentials, task creation, and accepted prompts.

Use normalized, low-cardinality properties. Never track prompts, credentials, URLs, domains, paths, response bodies, status text, parser details, exception messages, or new PII. One invocation is guaranteed; Heap ingestion remains best effort.

## Event Contract

| Event | Trigger | Properties |
|---|---|---|
| `authenticated_client_identified` | Successful `/api/user/me` parse, after `heap.identify` invocation | `framework` |
| `local_relay_discovery_completed` | Accepted non-aborted relay attempt settles | `framework`, `outcome`, optional `reason_code` |
| `provider_setup_blocker_shown` | Blocking modal changes hidden to visible | `framework` |
| `prompt_submission_initiated` | Chatbox accepts non-empty submission | `framework` |
| `task_creation_requested` | Accepted creation effect before `session/new` | `framework` |
| `prompt_request_sent` | Immediately before `session/prompt` transport | `framework` |

Allowed relay failure reasons: `http_error`, `invalid_response`, `network_error`.
