defmodule FrontmanServerWeb.TestSSOTest do
  use FrontmanServerWeb.ConnCase, async: false

  alias FrontmanServer.Accounts.UserIdentity
  alias FrontmanServer.Accounts.WorkOS, as: WorkOSAccounts

  setup do
    previous = Application.get_env(:frontman_server, :env)
    connection = Application.get_env(:frontman_server, :e2e_sso_connection_id)

    on_exit(fn ->
      Application.put_env(:frontman_server, :env, previous)

      case connection do
        nil -> Application.delete_env(:frontman_server, :e2e_sso_connection_id)
        value -> Application.put_env(:frontman_server, :e2e_sso_connection_id, value)
      end
    end)

    Application.put_env(:frontman_server, :e2e_sso_connection_id, "conn_test_sso")
    :ok
  end

  test "production refuses test SSO even with a configured connection", %{conn: conn} do
    Application.put_env(:frontman_server, :env, :prod)

    assert {:error, :test_sso_disabled} =
             WorkOSAccounts.get_authorization_url("sso", "https://frontman.test/auth/callback")

    assert get(conn, ~p"/auth/sso").status == 404

    refute UserIdentity.changeset(%UserIdentity{}, %{
             provider: "sso",
             provider_id: "user_test",
             user_id: Ecto.UUID.generate()
           }).valid?
  end

  test "E2E redirects through the configured real connection", %{conn: conn} do
    Application.put_env(:frontman_server, :env, :e2e)
    url = conn |> get(~p"/auth/sso") |> redirected_to()
    assert URI.parse(url).host == "api.workos.com"
    params = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    assert params["connection_id"] == "conn_test_sso"
    refute Map.has_key?(params, "provider")

    assert UserIdentity.changeset(%UserIdentity{}, %{
             provider: "sso",
             provider_id: "user_test",
             user_id: Ecto.UUID.generate()
           }).valid?
  end

  test "E2E without a connection refuses test SSO", %{conn: conn} do
    Application.put_env(:frontman_server, :env, :e2e)
    Application.delete_env(:frontman_server, :e2e_sso_connection_id)
    assert get(conn, ~p"/auth/sso").status == 404
  end
end
