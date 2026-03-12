defmodule FrontmanServerWeb.UserApiKeyController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Providers

  @doc """
  Stores a provider API key for the current user.
  """
  def create(conn, %{"provider" => provider, "key" => key}) do
    scope = conn.assigns.current_scope

    case Providers.upsert_api_key(scope, provider, key) do
      {:ok, _record} ->
        json(conn, %{status: "ok", provider: provider})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: translate_errors(changeset)})
    end
  end

  def usage(conn, params) do
    scope = conn.assigns.current_scope
    provider = params["provider"] || "openrouter"
    status = Providers.get_usage_status(scope, provider)

    json(conn, %{
      "limit" => status.limit,
      "used" => status.used,
      "remaining" => status.remaining,
      "hasUserKey" => status.has_user_key,
      "hasServerKey" => status.has_server_key
    })
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
