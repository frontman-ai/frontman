import Config

config :frontman_server, FrontmanServerWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :swoosh, api_client: Swoosh.ApiClient.Req

config :swoosh, local: false

config :logger, level: :info

config :sentry,
  dsn:
    "https://442ae992e5a5ccfc42e6910220aeb2a9@o4510512511320064.ingest.de.sentry.io/4510512546185296",
  environment_name: :prod,
  release: "frontman_server@#{Mix.Project.config()[:version]}",
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  tags: %{service: "frontman-server"}
