# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Application do
  @moduledoc false

  use Boundary, top_level?: true, deps: [FrontmanServer, FrontmanServerWeb]
  use Application

  alias FrontmanServer.Observability.ConsoleHandler

  @sentry_metadata [
    :file,
    :line,
    :error_type,
    :tool_name,
    :tool_call_id,
    :task_id,
    :user_id,
    :user_name,
    :reason,
    :error_code,
    :loop_id
  ]

  @reqllm_finch_client_file "lib/req_llm/streaming/finch_client.ex"

  @impl true
  def start(_type, _args) do
    if Application.get_env(:frontman_server, :env) == :dev do
      ConsoleHandler.setup()
    end

    :logger.add_handler(:sentry_handler, Sentry.LoggerHandler, %{
      filters: [reqllm_rate_limit_filter: {&__MODULE__.sentry_logger_filter/2, []}],
      config: %{
        capture_log_messages: true,
        level: :error,
        metadata: @sentry_metadata,
        tags_from_metadata: [:error_type, :tool_name, :task_id, :user_id]
      }
    })

    children = [
      FrontmanServerWeb.Telemetry,
      FrontmanServer.Repo,
      FrontmanServer.Vault,
      {DNSCluster, query: Application.get_env(:frontman_server, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FrontmanServer.PubSub},
      {SwarmAi, name: FrontmanServer.AgentRuntime},
      {Registry, keys: :unique, name: FrontmanServer.ToolCallRegistry},
      {Registry, keys: :duplicate, name: FrontmanServer.MCPConnectionRegistry},
      FrontmanServer.MCPConnectionState,
      mcp_recovery_child(),
      {Oban, Application.fetch_env!(:frontman_server, Oban)},
      FrontmanServerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: FrontmanServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp mcp_recovery_child do
    case Application.get_env(:frontman_server, :mcp_recovery_enabled, true) do
      true -> FrontmanServer.MCPRecovery
      false -> %{id: FrontmanServer.MCPRecovery, start: {Function, :identity, [:ignore]}}
    end
  end

  def sentry_logger_filter(%{msg: msg, meta: meta}, _opts) do
    message = logger_message_to_string(msg)
    file = logger_file_to_string(Map.get(meta, :file))

    case {reqllm_finch_client_file?(file), message} do
      {true, "Finch streaming failed: " <> rest} ->
        case String.contains?(rest, "status: 429") do
          true -> :stop
          false -> :ignore
        end

      _other ->
        :ignore
    end
  end

  defp logger_file_to_string(file) when is_binary(file), do: file
  defp logger_file_to_string(file) when is_list(file), do: IO.chardata_to_string(file)
  defp logger_file_to_string(_file), do: nil

  defp reqllm_finch_client_file?(nil), do: false
  defp reqllm_finch_client_file?(file), do: String.ends_with?(file, @reqllm_finch_client_file)

  defp logger_message_to_string({:string, chardata}), do: IO.chardata_to_string(chardata)

  defp logger_message_to_string({format, args}) when is_list(args) do
    format
    |> :io_lib.format(args)
    |> IO.chardata_to_string()
  end

  defp logger_message_to_string(message), do: inspect(message)

  @impl true
  def config_change(changed, _new, removed) do
    FrontmanServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
