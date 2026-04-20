defmodule FrontmanServerWeb.TaskChannelSandboxProvisioningTest do
  use FrontmanServerWeb.ChannelCase, async: false

  alias FrontmanServer.Sandbox.EnvironmentSpec

  @moduletag :capture_log

  defmodule StuckProvisionProvider do
    @behaviour FrontmanServer.Sandbox.Provider

    @impl true
    def create(%EnvironmentSpec{} = spec, _opts) do
      {:ok, "stuck-#{spec.name}-#{System.unique_integer([:positive])}"}
    end

    @impl true
    def exec(_ref, _command, _args, _opts), do: {:error, :not_ready}

    @impl true
    def metrics(_ref), do: {:ok, %{running: false}}

    @impl true
    def stop(_ref), do: :ok

    @impl true
    def start(_ref), do: :ok

    @impl true
    def destroy(_ref), do: :ok
  end

  setup do
    original_mvp_config = Application.get_env(:frontman_server, :sandbox_mvp, [])
    original_provider = Application.get_env(:frontman_server, :sandbox_provider)

    sandbox_mvp_config =
      original_mvp_config
      |> Keyword.put(:enabled, true)
      |> Keyword.put(:wait_timeout_ms, 400)
      |> Keyword.put(:poll_interval_ms, 20)

    Application.put_env(:frontman_server, :sandbox_mvp, sandbox_mvp_config)
    Application.put_env(:frontman_server, :sandbox_provider, StuckProvisionProvider)

    on_exit(fn ->
      Application.put_env(:frontman_server, :sandbox_mvp, original_mvp_config)

      case original_provider do
        nil -> Application.delete_env(:frontman_server, :sandbox_provider)
        provider -> Application.put_env(:frontman_server, :sandbox_provider, provider)
      end

      DynamicSupervisor.which_children(FrontmanServer.Sandbox.DynamicSupervisor)
      |> Enum.each(fn
        {_, pid, _, _} when is_pid(pid) -> Process.exit(pid, :kill)
        _ -> :ok
      end)
    end)

    :ok
  end

  test "channel remains responsive while sandbox provisioning is pending", %{scope: scope} do
    {socket, _task_id} = join_task_channel(scope)
    complete_mcp_handshake(socket)

    push(socket, "acp:message", build_prompt_request(id: 1, text: "Start"))

    ref =
      push(
        socket,
        "acp:message",
        build_acp_request("unknown/method", 2, %{})
      )

    assert_reply(ref, :ok, %{"acp:message" => %{"id" => 2, "error" => %{"code" => -32_601}}}, 150)

    assert_push(
      "acp:message",
      %{
        "params" => %{
          "update" => %{"sessionUpdate" => "error", "message" => ":sandbox_provisioning_timeout"}
        }
      },
      2_000
    )
  end
end
