# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.SubscriptionWebhook do
  @moduledoc """
  Synchronizes verified provider events across billing and subscriptions.
  """

  require Logger

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Analytics
  alias FrontmanServer.Billing
  alias FrontmanServer.{Repo, Tasks}

  @doc """
  Processes a verified Stripe webhook event idempotently.
  """
  def process_event(%{"id" => event_id, "type" => type} = event) do
    result =
      Repo.transact(fn ->
        case Billing.record_event(event) do
          {:ok, :inserted} ->
            Logger.info("stripe webhook processing event_id=#{event_id} type=#{type}")
            handle_event(type, event)

          {:ok, :duplicate} ->
            {:ok, :duplicate}

          {:error, reason} ->
            {:error, reason}
        end
      end)
      |> normalize_process_result()

    log_event_result(event_id, type, result)

    result
  end

  defp normalize_process_result({:ok, {:processed, scope, previous_access, access, attempt_id}}) do
    if previous_access != access do
      Analytics.track("subscription_access_changed", %{
        user_id: Scope.user_id(scope),
        onboarding_attempt_id: attempt_id,
        previous_access_status: access_status(previous_access),
        access_status: access_status(access),
        subscription_status: subscription_status(access)
      })
    end

    normalize_process_result({:ok, {:processed, scope}})
  end

  defp normalize_process_result({:ok, {:processed, scope}}) do
    :ok = Tasks.broadcast_status_changed(scope)
    {:ok, :processed}
  end

  defp normalize_process_result({:ok, result}), do: {:ok, result}

  defp normalize_process_result({:error, reason}), do: {:error, reason}

  defp access_status(:none), do: "none"
  defp access_status({status, _}), do: Atom.to_string(status)

  defp subscription_status(:none), do: "none"
  defp subscription_status({_, status}), do: status

  defp log_event_result(event_id, type, {:ok, result}) do
    Logger.info("stripe webhook #{result} event_id=#{event_id} type=#{type}")
  end

  defp log_event_result(event_id, type, {:error, reason}) do
    Logger.warning(
      "stripe webhook failed event_id=#{event_id} type=#{type} reason=#{inspect(reason)}"
    )
  end

  defp handle_event("checkout.session.completed", event) do
    session = event_object(event)
    user_id = session["client_reference_id"] || get_in(session, ["metadata", "user_id"])

    case user_id do
      nil ->
        {:ok, :ignored}

      user_id ->
        with %Scope{} = scope <-
               Scope.for_user(Accounts.get_user(user_id)) || {:error, :account_unavailable},
             {:ok, _customer} <- Billing.upsert_customer(scope, session["customer"]) do
          {:ok, {:processed, scope}}
        end
    end
  end

  defp handle_event("customer.subscription." <> action, event)
       when action in ["created", "updated", "deleted", "paused", "resumed"] do
    subscription = event_object(event)
    user_id = get_in(subscription, ["metadata", "user_id"])

    case user_id do
      nil ->
        {:ok, :ignored}

      user_id ->
        with %Scope{} = scope <-
               Scope.for_user(Accounts.get_user(user_id)) || {:error, :account_unavailable},
             {:ok, customer} <- Billing.upsert_customer(scope, subscription["customer"]),
             previous_access = Billing.subscription_access(scope),
             {:ok, _subscription} <-
               Billing.upsert_subscription(
                 scope,
                 customer,
                 subscription_attrs(subscription)
               ) do
          {:ok,
           {:processed, scope, previous_access, Billing.subscription_access(scope),
            onboarding_attempt_id(subscription)}}
        end
    end
  end

  defp handle_event(_type, _event), do: {:ok, :ignored}

  defp onboarding_attempt_id(subscription) do
    case Ecto.UUID.cast(get_in(subscription, ["metadata", "onboarding_attempt_id"])) do
      {:ok, id} -> id
      :error -> nil
    end
  end

  defp subscription_attrs(subscription) do
    first_item =
      subscription
      |> get_in(["items", "data"])
      |> case do
        items when is_list(items) -> Enum.at(items, 0)
        _items -> nil
      end

    first_item = first_item || %{}
    price = get_in(first_item, ["price"])

    %{
      stripe_subscription_id: subscription["id"],
      stripe_customer_id: subscription["customer"],
      status: subscription["status"],
      interval: subscription_interval(get_in(price || %{}, ["recurring", "interval"])),
      price_id: (price || %{})["id"],
      current_period_end:
        unix_to_datetime(subscription["current_period_end"] || first_item["current_period_end"]),
      trial_end: unix_to_datetime(subscription["trial_end"]),
      cancel_at: unix_to_datetime(subscription["cancel_at"]),
      canceled_at: unix_to_datetime(subscription["canceled_at"])
    }
  end

  defp event_object(event), do: get_in(event, ["data", "object"])

  defp subscription_interval("month"), do: :monthly
  defp subscription_interval("year"), do: :yearly
  defp subscription_interval(interval), do: interval

  defp unix_to_datetime(nil), do: nil

  defp unix_to_datetime(value) when is_integer(value), do: DateTime.from_unix!(value, :second)
end
