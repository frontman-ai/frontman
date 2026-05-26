import Config

config :frontman_notifier,
  start_scheduler: true,
  start_state: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:module]

import_config "#{config_env()}.exs"
