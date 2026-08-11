alias FrontmanServer.Accounts
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
    expires_at: DateTime.add(DateTime.utc_now(), 86_400, :second),
    metadata: %{"account_id" => account_id || "e2e-account"}
  })
  |> Repo.insert!()

  IO.puts("OpenAI OAuth token seeded for #{user.email}")
else
  IO.puts("Skipping OpenAI token seed — set E2E_OPENAI_ACCESS_TOKEN and E2E_OPENAI_REFRESH_TOKEN")
end
