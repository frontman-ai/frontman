defmodule FrontmanServer.Workers.NotifyDiscordNewUserTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Test.Fixtures.Accounts
  alias FrontmanServer.Workers.NotifyDiscordNewUser

  setup do
    Application.put_env(:frontman_server, :notify_discord_req_options,
      plug: {Req.Test, :discord_webhook}
    )

    on_exit(fn ->
      Application.delete_env(:frontman_server, :notify_discord_req_options)
    end)

    :ok
  end

  describe "perform/1" do
    test "posts new-user embed to the configured Discord webhook" do
      user = Accounts.user_fixture(%{name: "Ada Lovelace", email: "ada@example.com"})

      Req.Test.stub(:discord_webhook, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        [embed] = payload["embeds"]
        assert embed["title"] == "New User Signed Up"
        assert embed["color"] == 0x57F287

        fields = Map.new(embed["fields"], &{&1["name"], &1["value"]})
        assert fields["Name"] == "Ada Lovelace"
        assert fields["Email"] == "ada@example.com"

        Req.Test.json(conn, %{ok: true})
      end)

      assert :ok = perform_job(NotifyDiscordNewUser, %{user_id: user.id})
    end

    test "returns error tuple on non-2xx response" do
      user = Accounts.user_fixture()

      Req.Test.stub(:discord_webhook, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"message" => "rate limited"}))
      end)

      assert {:error, _reason} = perform_job(NotifyDiscordNewUser, %{user_id: user.id})
    end

    test "discards the job when user does not exist" do
      assert :discard = perform_job(NotifyDiscordNewUser, %{user_id: Ecto.UUID.generate()})
    end

    test "enqueues with correct queue" do
      user = Accounts.user_fixture()
      changeset = NotifyDiscordNewUser.new(%{user_id: user.id})

      assert changeset.changes.queue == "notifications"
    end
  end
end
