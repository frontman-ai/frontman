defmodule FrontmanServer.Test.BillingClientStub do
  @moduledoc false

  @behaviour FrontmanServer.Billing.Client

  @customer_portal_url_result_key {
    __MODULE__,
    :customer_portal_url_result
  }

  @stripe_checkout_result_key {
    __MODULE__,
    :stripe_checkout_result
  }

  def stub_start_checkout(result) do
    Process.put(@stripe_checkout_result_key, result)
  end

  def stub_customer_portal_url(result) do
    Process.put(@customer_portal_url_result_key, result)
  end

  @impl true
  def create_customer_portal_url(customer, return_url) do
    send(self(), {:create_customer_portal_url, customer, return_url})

    Process.get(@customer_portal_url_result_key)
  end

  @impl true
  def start_checkout(user, customer, interval, return_urls, opts) do
    send(self(), {:start_checkout, user, customer, interval, return_urls, opts})

    case Process.get(@stripe_checkout_result_key, :unexpected_checkout) do
      :unexpected_checkout -> raise "unexpected checkout through billing client stub"
      result -> result
    end
  end

  @impl true
  def construct_webhook_event(_raw_body, _signature_header) do
    raise "unexpected webhook construction through billing client stub"
  end
end
