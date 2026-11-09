defmodule FrontmanServerWeb.DomainVerificationControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  test "GET challenge returns the exact token as plain text without authentication", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "text/plain")
      |> get(~p"/.well-known/openai-apps-challenge")

    assert response(conn, 200) == "ZKaJ79L0oIFTbrUjo92f45gdd0Zo8GSeGmgmzprrPiw"
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
    assert get_resp_header(conn, "location") == []
    assert get_resp_header(conn, "set-cookie") == []
  end

  test "HEAD challenge succeeds without a response body", %{conn: conn} do
    conn = head(conn, ~p"/.well-known/openai-apps-challenge")

    assert response(conn, 200) == ""
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end
end
