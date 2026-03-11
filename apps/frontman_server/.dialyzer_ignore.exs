[
  # Ecto.Multi returns an opaque type that dialyzer doesn't understand well
  {"lib/frontman_server/organizations.ex", :call_without_opaque},
  # New SwarmAi helper functions — PLT cache may be stale across fresh builds.
  # These functions exist in apps/swarm_ai but Dialyzer's cached PLT may not
  # include them yet. Safe to remove once PLT cache rebuilds cleanly.
  {"lib/frontman_server/observability/swarm_otel_handler.ex", :call_to_missing},
  {"lib/frontman_server/tasks/execution/llm_client.ex", :call_to_missing}
]
