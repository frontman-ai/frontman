Logger.put_module_level(ReqLLM.Streaming, :none)
Logger.put_module_level(ReqLLM.StreamServer, :none)
Logger.put_module_level(ReqLLM.StreamResponse.MetadataHandle, :none)

ExUnit.start()

Mox.defmock(
  FrontmanServer.Tasks.Execution.LLMProviderMock,
  for: FrontmanServer.Tasks.Execution.LLMProvider
)

Ecto.Adapters.SQL.Sandbox.mode(FrontmanServer.Repo, :manual)
