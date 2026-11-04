defmodule FrontmanServerWeb.MCP.Server do
  @moduledoc false

  @server_name Mix.Project.config()[:app] |> Atom.to_string()
  @server_version Mix.Project.config()[:version]

  use Anubis.Server, name: @server_name, version: @server_version, capabilities: [:tools]

  alias Anubis.MCP.Error
  alias Anubis.Server.{Component.Tool, Frame, Response}
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.WordPress

  @impl true
  def server_tools(tools, _frame) do
    [
      %Tool{
        name: "list_sites",
        description: "List WordPress sites connected to your Frontman account.",
        input_schema: %{"type" => "object", "properties" => %{}},
        validate_input: fn args -> {:ok, args} end
      }
      | tools
    ]
  end

  @impl true
  def handle_tool_call("list_sites", _arguments, frame) do
    with subject when is_binary(subject) <- Frame.subject(frame),
         {:ok, id} <- Ecto.UUID.cast(subject),
         user when not is_nil(user) <- Accounts.get_user(id) do
      sites = user |> Scope.for_user() |> WordPress.list_sites()
      {:reply, Response.json(Response.tool(), %{sites: sites}), frame}
    else
      _ -> {:error, Error.execution("Account unavailable"), frame}
    end
  end
end
