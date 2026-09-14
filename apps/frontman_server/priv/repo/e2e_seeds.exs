defmodule FrontmanServer.E2ESeeds do
  @moduledoc false

  def access_token_expires_at!(access_token) when is_binary(access_token) do
    case decode_jwt_claims(access_token) do
      {:ok, %{"exp" => exp}} when is_integer(exp) ->
        exp
        |> DateTime.from_unix!()
        |> require_unexpired_access_token!()

      {:ok, _claims} ->
        raise "E2E_OPENAI_ACCESS_TOKEN is missing an exp claim; refresh the E2E OpenAI token secret"

      {:error, reason} ->
        raise "E2E_OPENAI_ACCESS_TOKEN is not a valid JWT: #{inspect(reason)}"
    end
  end

  defp require_unexpired_access_token!(expires_at) do
    minimum_expires_at = DateTime.add(DateTime.utc_now(), 300, :second)

    case DateTime.compare(expires_at, minimum_expires_at) do
      :gt ->
        expires_at

      _ ->
        raise "E2E_OPENAI_ACCESS_TOKEN expires too soon; refresh the E2E OpenAI token secret"
    end
  end

  defp decode_jwt_claims(access_token) do
    with [_header, payload, _signature] <- String.split(access_token, "."),
         {:ok, json} <- Base.url_decode64(payload, padding: false),
         {:ok, claims} <- Jason.decode(json) do
      {:ok, claims}
    else
      [_header, _payload | _extra] -> {:error, :invalid_segment_count}
      [_header | _extra] -> {:error, :invalid_segment_count}
      _ -> {:error, :invalid_jwt}
    end
  end
end

alias FrontmanServer.Accounts
alias FrontmanServer.E2ESeeds
alias FrontmanServer.Providers.OAuthToken
alias FrontmanServer.Repo

e2e_email = "e2e@frontman.local"
e2e_password = "e2epassword123!"

user =
  case Accounts.get_user_by_email(e2e_email) do
    nil ->
      {:ok, user} =
        Accounts.register_user(%{
          email: e2e_email,
          name: "E2E Test User",
          password: e2e_password
        })

      user
      |> Accounts.User.confirm_changeset()
      |> Repo.update!()

    existing ->
      existing
  end

IO.puts("E2E user: #{user.email} (id: #{user.id})")

access_token = System.get_env("E2E_OPENAI_ACCESS_TOKEN")
refresh_token = System.get_env("E2E_OPENAI_REFRESH_TOKEN")
account_id = System.get_env("E2E_OPENAI_ACCOUNT_ID")
token_present? = fn value -> is_binary(value) and value != "" end

if token_present?.(access_token) and token_present?.(refresh_token) do
  OAuthToken.for_user_and_provider(user.id, "openai_codex")
  |> Repo.delete_all()

  %OAuthToken{user_id: user.id}
  |> OAuthToken.changeset(%{
    provider: "openai_codex",
    access_token: access_token,
    refresh_token: refresh_token,
    expires_at: E2ESeeds.access_token_expires_at!(access_token),
    metadata: %{"account_id" => account_id || "e2e-account"}
  })
  |> Repo.insert!()

  IO.puts("OpenAI OAuth token seeded for #{user.email}")
else
  IO.puts("Skipping OpenAI token seed — set E2E_OPENAI_ACCESS_TOKEN and E2E_OPENAI_REFRESH_TOKEN")
end
