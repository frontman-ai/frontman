defmodule FrontmanServer.Test.Fixtures.Onboarding do
  @moduledoc "Persisted synthetic accounts for hosted setup browser checks and screenshots."

  use Boundary,
    top_level?: true,
    check: [in: false, out: false]

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.BillingFixtures
  alias FrontmanServer.Repo
  alias FrontmanServer.WordPress.Connection

  def cases(password) do
    [
      create("new-site", password, 0, :none),
      create("trial-offer", password, 1, :none),
      create("ready", password, 1, :active),
      create("choose-site", password, 2, :active),
      create("returning", password, 1, :canceled)
    ]
  end

  defp create(name, password, site_count, subscription) do
    {:ok, user} =
      Accounts.register_user(%{email: "#{name}@fern-studio.example", name: "Maya Chen"})

    user = user |> Accounts.User.confirm_changeset() |> Repo.update!()
    {:ok, {_user, _tokens}} = Accounts.update_user_password(user, %{password: password})
    scope = Scope.for_user(user)

    case subscription do
      :active ->
        BillingFixtures.subscription_for_scope_fixture(scope, %{status: "active"})

      :canceled ->
        BillingFixtures.subscription_for_scope_fixture(scope, %{
          status: "canceled",
          trial_end: DateTime.add(DateTime.utc_now(:second), -86_400)
        })

      :none ->
        :ok
    end

    sites =
      Enum.take(["fern-studio.example", "field-notes.example"], site_count)
      |> Enum.map(&site(user.id, &1))

    %{name: name, email: user.email, user_id: user.id, site_ids: Enum.map(sites, & &1.id)}
  end

  defp site(user_id, hostname) do
    # A saved connection fixture does not claim a live credential or permission check.
    Repo.insert!(%Connection{
      user_id: user_id,
      catalog_url: "https://#{hostname}/wp-json/frontman/v1/mcp",
      call_url: "https://#{hostname}/wp-json/frontman/v1/mcp/call",
      username: "local-browser-fixture",
      password: Base.url_encode64(:crypto.strong_rand_bytes(32))
    })
  end
end
