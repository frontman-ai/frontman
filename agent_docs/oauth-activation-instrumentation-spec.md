# Spec: OAuth Activation Instrumentation

Measure relay completion in Heap without duplicating milestones already observable through Heap identity/autocapture or PostgreSQL.

Use normalized, low-cardinality properties. Never track prompts, credentials, URLs, domains, paths, response bodies, status text, parser details, exception messages, or new PII. One invocation is guaranteed; Heap ingestion remains best effort.

## Event Contract

| Event | Trigger | Properties |
|---|---|---|
| `relay_connection_completed` | Accepted non-aborted relay attempt settles | `framework`, `outcome`, optional `reason_code` |

Allowed relay failure reasons: `http_error`, `invalid_response`, `network_error`.

Use identified Heap pageviews and autocaptured UI actions as client proxies. PostgreSQL remains authoritative for OAuth completion, credentials, task creation, and accepted prompts. Autocapture does not prove blocker impressions or keyboard-submitted prompts.
