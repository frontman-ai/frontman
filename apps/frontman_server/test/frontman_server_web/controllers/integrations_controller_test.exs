defmodule FrontmanServerWeb.IntegrationsControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  @cache_key {FrontmanServerWeb.IntegrationsController, :cache}
  @wordpress_key "wordpress:frontman-agentic-ai-editor"

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup do
    previous_config =
      Application.get_env(:frontman_server, FrontmanServerWeb.IntegrationsController)

    Application.put_env(:frontman_server, FrontmanServerWeb.IntegrationsController,
      req_options: [plug: {Req.Test, :integration_versions}, retry: false]
    )

    :persistent_term.erase(@cache_key)

    on_exit(fn ->
      :persistent_term.erase(@cache_key)

      case previous_config do
        nil ->
          Application.delete_env(:frontman_server, FrontmanServerWeb.IntegrationsController)

        config ->
          Application.put_env(
            :frontman_server,
            FrontmanServerWeb.IntegrationsController,
            config
          )
      end
    end)
  end

  test "returns npm and WordPress versions together and sends the plugin slug", %{conn: conn} do
    test_pid = self()

    stub_registries(fn wordpress_conn ->
      wordpress_conn = Plug.Conn.fetch_query_params(wordpress_conn)
      send(test_pid, {:wordpress_query, wordpress_conn.query_params})
      Req.Test.json(wordpress_conn, %{"version" => "1.8.0"})
    end)

    response = conn |> get(~p"/api/integrations/latest-versions") |> json_response(200)

    assert response["versions"] == %{
             "@frontman-ai/astro" => "1.2.3",
             "@frontman-ai/nextjs" => "1.2.3",
             "@frontman-ai/vite" => "1.2.3",
             @wordpress_key => "1.8.0"
           }

    assert_receive {:wordpress_query, query}
    assert query["action"] == "plugin_information"
    assert query["request"]["slug"] == "frontman-agentic-ai-editor"
  end

  test "keeps npm versions when WordPress.org fails", %{conn: conn} do
    stub_registries(&Req.Test.transport_error(&1, :closed))

    response = conn |> get(~p"/api/integrations/latest-versions") |> json_response(200)

    assert response["versions"][@wordpress_key] == nil
    assert response["versions"]["@frontman-ai/nextjs"] == "1.2.3"
  end

  test "returns nil for malformed or missing WordPress versions", %{conn: conn} do
    {:ok, count} = Agent.start_link(fn -> 0 end)

    stub_registries(fn wordpress_conn ->
      request_number = Agent.get_and_update(count, &{&1, &1 + 1})

      case request_number do
        0 -> Req.Test.json(wordpress_conn, %{"version" => ""})
        1 -> Req.Test.json(wordpress_conn, %{})
      end
    end)

    first = conn |> get(~p"/api/integrations/latest-versions") |> json_response(200)
    assert first["versions"][@wordpress_key] == nil

    :persistent_term.erase(@cache_key)
    second = conn |> recycle() |> get(~p"/api/integrations/latest-versions") |> json_response(200)
    assert second["versions"][@wordpress_key] == nil
  end

  test "uses cached versions during the TTL", %{conn: conn} do
    {:ok, count} = Agent.start_link(fn -> 0 end)

    Req.Test.stub(:integration_versions, fn request_conn ->
      Agent.update(count, &(&1 + 1))
      registry_response(request_conn, &Req.Test.json(&1, %{"version" => "1.8.0"}))
    end)

    first = conn |> get(~p"/api/integrations/latest-versions") |> json_response(200)
    second = conn |> recycle() |> get(~p"/api/integrations/latest-versions") |> json_response(200)

    assert first == second
    assert Agent.get(count, & &1) == 4
  end

  defp stub_registries(wordpress_response) do
    Req.Test.stub(:integration_versions, &registry_response(&1, wordpress_response))
  end

  defp registry_response(%Plug.Conn{host: "registry.npmjs.org"} = conn, _wordpress_response) do
    Req.Test.json(conn, %{"version" => "1.2.3"})
  end

  defp registry_response(%Plug.Conn{host: "api.wordpress.org"} = conn, wordpress_response) do
    wordpress_response.(conn)
  end
end
