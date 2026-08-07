defmodule FrontmanServerWeb.UserApiKeyController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Providers

  def index(conn, _params) do
    scope = conn.assigns.current_scope

    json(conn, %{"providers" => Providers.list_api_key_providers(scope)})
  end

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

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
