defmodule FrontmanServerWeb.MCP.ReadWordPressPost do
  @moduledoc "Read a post through an owned WordPress connection."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.{Frame, Response}
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.WordPress

  schema do
    field(:connection_id, :string, required: true)
    field(:post_id, :integer, required: true)
  end

  @impl true
  def execute(%{connection_id: id, post_id: post_id}, frame) do
    result =
      with subject when is_binary(subject) <- Frame.subject(frame),
           user when not is_nil(user) <- Accounts.get_user(subject),
           {:ok, %{"isError" => false, "content" => [%{"text" => text} | _]}}
           when is_binary(text) <- WordPress.read_post(Scope.for_user(user), id, post_id) do
        Response.text(Response.tool(), text)
      else
        _ -> Response.error(Response.tool(), "Unable to read this post.")
      end

    {:reply, result, frame}
  end
end
