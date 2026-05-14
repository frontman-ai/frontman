# Suppress noisy logs from ReqLLM dependency when LLM calls fail with
# expected auth errors (401) in tests that don't provide real API keys.
Logger.put_module_level(ReqLLM.Streaming, :none)
Logger.put_module_level(ReqLLM.StreamServer, :none)
Logger.put_module_level(ReqLLM.StreamResponse.MetadataHandle, :none)

ExUnit.start()

Mox.defmock(
  FrontmanServer.Tasks.Execution.LLMProviderMock,
  for: FrontmanServer.Tasks.Execution.LLMProvider
)

Ecto.Adapters.SQL.Sandbox.mode(FrontmanServer.Repo, :manual)
