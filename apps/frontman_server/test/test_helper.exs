Logger.put_module_level(ReqLLM.Streaming, :none)
Logger.put_module_level(ReqLLM.StreamServer, :none)
Logger.put_module_level(ReqLLM.StreamResponse.MetadataHandle, :none)

{:ok, _} = Application.ensure_all_started(:paper_tiger)
stripe_config = Application.fetch_env!(:frontman_server, :stripe)

Application.put_env(
  :frontman_server,
  :stripe,
  Keyword.put(stripe_config, :api_base_url, PaperTiger.Test.base_url("/v1"))
)

ExUnit.start(exclude: [:application_restart])

Mox.defmock(
  FrontmanServer.Tasks.Execution.LLMProviderMock,
  for: FrontmanServer.Tasks.Execution.LLMProvider
)

Ecto.Adapters.SQL.Sandbox.mode(FrontmanServer.Repo, :manual)
