defmodule FrontmanServer.SessionsTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Sessions

  setup do
    session_id = "test-#{:rand.uniform(1_000_000)}"
    {:ok, session_id: session_id}
  end

  describe "create_session/1" do
    test "creates session in :awaiting_caps state", %{session_id: session_id} do
      {:ok, session} = Sessions.create_session(session_id)
      assert session.session_id == session_id
      assert session.state == :awaiting_caps
      assert session.capabilities == %{}
    end
  end

  describe "register_capabilities/2" do
    test "accepts capabilities in :awaiting_caps state", %{session_id: session_id} do
      {:ok, _} = Sessions.create_session(session_id)

      caps = [
        %{"name" => "log_message", "description" => "Log to console", "inputSchema" => %{}}
      ]

      {:ok, session} = Sessions.register_capabilities(session_id, caps)
      assert session.state == :ready
      assert Map.has_key?(session.capabilities, "log_message")
    end

    test "rejects capabilities if already registered", %{session_id: session_id} do
      {:ok, _} = Sessions.create_session(session_id)

      caps = [%{"name" => "test", "description" => "", "inputSchema" => %{}}]
      {:ok, _} = Sessions.register_capabilities(session_id, caps)

      assert {:error, :already_registered} = Sessions.register_capabilities(session_id, caps)
    end
  end

  describe "mark_disconnected/1 and prepare_reconnect/1" do
    test "handles disconnect/reconnect cycle", %{session_id: session_id} do
      {:ok, _} = Sessions.create_session(session_id)

      caps = [%{"name" => "test", "description" => "", "inputSchema" => %{}}]
      {:ok, _} = Sessions.register_capabilities(session_id, caps)

      # Disconnect
      {:ok, session} = Sessions.mark_disconnected(session_id)
      assert session.state == :disconnected
      assert session.disconnected_at != nil

      # Reconnect
      {:ok, session} = Sessions.prepare_reconnect(session_id)
      assert session.state == :awaiting_caps
      assert session.disconnected_at == nil
      assert session.capabilities == %{}
    end
  end

  describe "transition/2" do
    test "allows :awaiting_caps -> :ready via :capabilities_registered" do
      assert {:ok, :ready} = Sessions.transition(:awaiting_caps, :capabilities_registered)
    end

    test "allows :ready -> :disconnected via :disconnected event" do
      assert {:ok, :disconnected} = Sessions.transition(:ready, :disconnected)
    end

    test "allows :disconnected -> :awaiting_caps via :reconnect" do
      assert {:ok, :awaiting_caps} = Sessions.transition(:disconnected, :reconnect)
    end

    test "allows any state -> :terminated via :terminate" do
      assert {:ok, :terminated} = Sessions.transition(:awaiting_caps, :terminate)
      assert {:ok, :terminated} = Sessions.transition(:ready, :terminate)
      assert {:ok, :terminated} = Sessions.transition(:disconnected, :terminate)
    end

    test "rejects :disconnected -> :ready (must re-announce caps)" do
      assert {:error, :invalid_transition} =
               Sessions.transition(:disconnected, :capabilities_registered)
    end

    test "rejects transitions from :terminated" do
      assert {:error, :invalid_transition} = Sessions.transition(:terminated, :reconnect)
    end
  end
end
