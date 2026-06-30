defmodule FrontmanServerWeb.HealthControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  setup do
    on_exit(fn -> reset_drain() end)
  end

  test "GET /health returns liveness", %{conn: conn} do
    conn = get(conn, ~p"/health")

    assert json_response(conn, 200) == %{"status" => "ok"}
  end

  test "GET /ready returns readiness without database status", %{conn: conn} do
    conn = get(conn, ~p"/ready")

    assert json_response(conn, 200) == %{"status" => "ready"}
  end

  test "GET /ready reflects drain readiness", %{conn: conn} do
    assert FrontmanServer.Drain.ready?()

    conn = get(conn, ~p"/ready")

    assert json_response(conn, 200) == %{"status" => "ready"}
  end

  test "GET /ready returns 503 while draining", %{conn: conn} do
    assert :ok = FrontmanServer.Drain.start_draining()

    conn = get(conn, ~p"/ready")

    assert json_response(conn, 503) == %{"status" => "draining"}
  end

  test "GET /health/ready remains a compatibility readiness route", %{conn: conn} do
    conn = get(conn, ~p"/health/ready")

    assert json_response(conn, 200) == %{"status" => "ready"}
  end

  defp reset_drain do
    :sys.replace_state(FrontmanServer.Drain, fn _draining? -> false end)
    assert FrontmanServer.Drain.ready?()
  end
end
