defmodule FrontmanServer.StripeIntegrationCase do
  @moduledoc """
  Helpers for Stripe workflow tests backed by PaperTiger.

  Integration tests opt in with `setup :setup_paper_tiger` for PaperTiger
  namespace isolation and deterministic product/price data.
  """

  import ExUnit.Assertions

  def setup_paper_tiger(_context) do
    {:ok, _apps} = Application.ensure_all_started(:paper_tiger)
    :ok = PaperTiger.Test.checkout_paper_tiger()

    seed_paper_tiger!()

    :ok
  end

  def setup_paper_tiger_webhook(context) do
    :ok = setup_paper_tiger(context)

    previous_mode = Application.get_env(:paper_tiger, :webhook_mode)
    Application.put_env(:paper_tiger, :webhook_mode, :sync)

    ExUnit.Callbacks.on_exit(fn ->
      case previous_mode do
        nil -> Application.delete_env(:paper_tiger, :webhook_mode)
        mode -> Application.put_env(:paper_tiger, :webhook_mode, mode)
      end
    end)

    {:ok, _webhook} =
      PaperTiger.register_webhook(
        url: endpoint_url("/api/stripe/webhook"),
        secret: stripe_config!(:webhook_secret),
        events: ["checkout.session.completed", "customer.subscription.created"]
      )

    :ok
  end

  def endpoint_url(path \\ "") do
    {:ok, {_address, port}} = Bandit.PhoenixAdapter.server_info(FrontmanServerWeb.Endpoint, :http)

    "http://localhost:#{port}#{path}"
  end

  def assert_paper_tiger_checkout_session!(%{"id" => session_id, "url" => checkout_url}) do
    assert String.starts_with?(session_id, "cs_")

    assert checkout_url ==
             "http://localhost:#{PaperTiger.get_port()}/checkout/#{session_id}/complete"

    {session_id, checkout_url}
  end

  defp seed_paper_tiger! do
    {:ok, _stats} = PaperTiger.Initializer.load()
    :ok
  end

  defp stripe_config!(key) do
    :frontman_server
    |> Application.fetch_env!(:stripe)
    |> Keyword.fetch!(key)
  end
end
