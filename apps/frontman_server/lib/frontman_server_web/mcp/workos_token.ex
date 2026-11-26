defmodule FrontmanServerWeb.MCP.WorkOSToken do
  @moduledoc false
  @behaviour Anubis.Server.Authorization.Validator

  alias Anubis.Server.Authorization
  alias Anubis.Server.Authorization.JWTValidator
  alias FrontmanServer.Accounts
  alias FrontmanServerWeb.MCP.Lifecycle

  @impl true
  def validate_token(token, context) when is_binary(token) and byte_size(token) <= 4_096 do
    with true <- valid_header?(token),
         {:ok, claims} <-
           JWTValidator.validate_token(token, context),
         %{"sub" => subject, "exp" => expiry, "client_id" => client_id} <- claims,
         true <- is_integer(expiry),
         :ok <- Authorization.validate_expiry(Authorization.normalize_claims(claims)),
         :ok <- Authorization.validate_audience(Authorization.normalize_claims(claims), context),
         true <- valid_not_before?(claims),
         true <- is_binary(client_id) and client_id != "",
         {:ok, id} <- Ecto.UUID.cast(subject),
         user when not is_nil(user) <- Accounts.get_user(id) do
      Lifecycle.authenticated(id, client_id, Authorization.normalize_claims(claims))
      {:ok, claims}
    else
      {:error, reason} -> reject(Authorization.outcome(reason))
      _ -> reject(:invalid_token)
    end
  end

  def validate_token(_token, _context), do: reject(:invalid_token)

  defp reject(reason) do
    Lifecycle.authentication_failed(reason)
    {:error, reason}
  end

  defp valid_header?(token) do
    with [protected, _, _] <- String.split(token, "."),
         {:ok, json} <- Base.url_decode64(protected, padding: false),
         {:ok, %{"alg" => "RS256", "kid" => kid} = header} <- Jason.decode(json),
         true <- is_binary(kid) and kid != "",
         false <- Map.has_key?(header, "crit") do
      true
    else
      _ -> false
    end
  end

  defp valid_not_before?(%{"nbf" => value}) when is_integer(value),
    do: value <= System.system_time(:second)

  defp valid_not_before?(%{"nbf" => _}), do: false
  defp valid_not_before?(_claims), do: true
end
