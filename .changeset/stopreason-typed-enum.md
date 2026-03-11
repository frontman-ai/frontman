---
"@frontman/frontman-protocol": minor
"@frontman/client": patch
---

Make StopReason a typed enum per ACP spec instead of a raw string. Defines the 5 ACP-specified values (end_turn, max_tokens, max_turn_requests, refusal, cancelled) as a closed variant type in the protocol layer, with corresponding Elixir module attributes and guard clauses on the server side.
