defmodule FrontmanServerWeb.WordPressBrowserRuntimeTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures
  alias FrontmanServer.WordPress
  alias FrontmanServer.WordPress.Connection

  @tag :wordpress_browser_runtime
  @tag timeout: 240_000
  @tag skip: System.get_env("FRONTMAN_WP_BROWSER_URL") == nil
  test "the standalone client connects a real WordPress site and changes access" do
    root = Path.expand("../../../..", __DIR__)
    origin = System.fetch_env!("FRONTMAN_WP_BROWSER_URL")
    runtime = System.fetch_env!("CONTAINER_RUNTIME")
    container = System.fetch_env!("FRONTMAN_WP_BROWSER_CONTAINER")
    directory = System.fetch_env!("FRONTMAN_WP_BROWSER_DIRECTORY")
    previous_env = Application.get_env(:frontman_server, :env)
    Application.put_env(:frontman_server, :env, :dev)
    :public_key.cacerts_clear()

    :ok =
      :public_key.cacerts_load(String.to_charlist(System.fetch_env!("FRONTMAN_WP_BROWSER_CA")))

    on_exit(fn ->
      if previous_env,
        do: Application.put_env(:frontman_server, :env, previous_env),
        else: Application.delete_env(:frontman_server, :env)

      :public_key.cacerts_clear()
    end)

    server =
      start_supervised!(
        {Bandit,
         plug: FrontmanServerWeb.Endpoint,
         scheme: :https,
         ip: {127, 0, 0, 1},
         port: 0,
         certfile: System.fetch_env!("FRONTMAN_WP_BROWSER_CERT"),
         keyfile: System.fetch_env!("FRONTMAN_WP_BROWSER_KEY")}
      )

    {:ok, {_, port}} = ThousandIsland.listener_info(server)
    host = "127.0.0.1:#{port}"
    blocked_log = Path.join(directory, "browser-blocked-connections")

    proxy =
      Port.open(
        {:spawn_executable, System.find_executable("python3")},
        [
          :binary,
          :exit_status,
          {:line, 128},
          args: [
            Path.join(root, "libs/frontman-wordpress/tests/integration/BrowserRuntimeProxy.py"),
            Integer.to_string(URI.parse(origin).port),
            Integer.to_string(port),
            blocked_log
          ]
        ]
      )

    [proxy_port, blocked_port] =
      receive do
        {^proxy, {:data, {:eol, line}}} -> String.split(line)
      after
        10_000 -> flunk("Browser network proxy did not start")
      end

    user = AccountsFixtures.user_fixture()
    token = Accounts.generate_embedded_client_token(user, origin)

    second_token =
      Accounts.generate_embedded_client_token(AccountsFixtures.user_fixture(), origin)

    token_path = Path.join(directory, "browser-token")
    second_token_path = Path.join(directory, "browser-second-token")
    password_path = Path.join(directory, "browser-password")
    File.write!(token_path, token)
    File.chmod!(token_path, 0o600)
    File.write!(second_token_path, second_token)
    File.chmod!(second_token_path, 0o600)

    {_, 0} =
      System.cmd(runtime, [
        "exec",
        "-e",
        "FRONTMAN_BROWSER_ORIGIN=#{origin}",
        "-e",
        "FRONTMAN_BROWSER_SERVER_HOST=#{host}",
        container,
        "php",
        "/tmp/BrowserRuntimeFixture.php",
        "setup"
      ])

    on_exit(fn ->
      {_, 0} =
        System.cmd(runtime, [
          "exec",
          container,
          "php",
          "/tmp/BrowserRuntimeFixture.php",
          "restore"
        ])
    end)

    {_, 0} =
      System.cmd(runtime, ["cp", "#{container}:/tmp/frontman-browser-password", password_path])

    File.chmod!(password_path, 0o600)

    {output, status} =
      System.cmd(
        "make",
        [
          "-C",
          "libs/client",
          "test",
          "TEST_FILTER=test/Client__WordPressBrowser.test.res.mjs"
        ],
        cd: root,
        stderr_to_stdout: true,
        env: [
          {"FRONTMAN_WP_BROWSER_URL", origin},
          {"FRONTMAN_WP_BROWSER_PHOENIX_URL", "https://#{host}"},
          {"FRONTMAN_WP_BROWSER_PASSWORD", password_path},
          {"FRONTMAN_WP_BROWSER_TOKEN", token_path},
          {"FRONTMAN_WP_BROWSER_TOKEN_SECOND", second_token_path},
          {"FRONTMAN_WP_BROWSER_PROXY_PORT", proxy_port},
          {"FRONTMAN_WP_BROWSER_BLOCKED_PORT", blocked_port},
          {"FRONTMAN_WP_BROWSER_SPKI", System.fetch_env!("FRONTMAN_WP_BROWSER_SPKI")}
        ]
      )

    assert status == 0, output
    assert {:error, :enoent} = File.read(blocked_log)
    assert [connection] = Repo.all(from c in Connection, where: c.user_id == ^user.id)

    assert {:ok, %{"tools" => [_ | _]}} =
             WordPress.catalog(Scope.for_user(user), connection.id, 5_000)

    assert {_, 0} =
             System.cmd(runtime, [
               "exec",
               container,
               "php",
               "/tmp/BrowserRuntimeFixture.php",
               "verify"
             ])
  end
end
