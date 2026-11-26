defmodule FrontmanServer.Test.SentryFixture do
  @moduledoc "Collects Sentry reports in the test scope and accepts envelopes over Bandit."

  alias FrontmanServer.Test.HTTPFixture
  alias Sentry.Test.Config

  def start! do
    base_url =
      HTTPFixture.start!(%{{"POST", "/api/1/envelope/"} => :any}, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"id":"#{Sentry.UUID.uuid4_hex()}"}))
      end)

    uri = URI.parse(base_url)
    dsn = URI.to_string(%{uri | userinfo: "public:secret", path: "/1"})

    Sentry.Test.setup_client_report_sender()
    :ok = Sentry.Test.start_collecting_sentry_reports()
    Config.put(dsn: dsn, dedup_events: false)
  end
end
