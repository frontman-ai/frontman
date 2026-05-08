# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Billing.Webhooks do
  @moduledoc """
  Stripe webhook ingestion for billing lifecycle events.
  """

  require Logger

  alias FrontmanServer.Billing.{Customer, StripeEvent, Subscription}
  alias FrontmanServer.Repo

  @doc """
  Processes a verified Stripe webhook event idempotently.
  """
  @spec process_event(map()) :: {:ok, :processed | :ignored | :duplicate} | {:error, term()}
  def process_event(%{"id" => event_id, "type" => type} = event) do
    result =
      Repo.transaction(fn -> process_event_in_transaction(event_id, type, event) end)
      |> case do
        {:ok, {:ok, result}} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end

    log_event_result(event_id, type, result)

    result
  end

  defp process_event_in_transaction(event_id, type, event) do
    case insert_event(event_id, type, event) do
      {:ok, :duplicate} -> {:ok, :duplicate}
      {:ok, :inserted} -> process_inserted_event(event_id, type, event)
    end
  end

  defp process_inserted_event(event_id, type, event) do
    Logger.info("stripe webhook processing event_id=#{event_id} type=#{type}")

    case handle_event(type, event) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp log_event_result(event_id, type, {:ok, result}) do
    Logger.info("stripe webhook #{result} event_id=#{event_id} type=#{type}")
  end

  defp log_event_result(event_id, type, {:error, reason}) do
    Logger.warning(
      "stripe webhook failed event_id=#{event_id} type=#{type} reason=#{inspect(reason)}"
    )
  end

  defp insert_event(event_id, type, event) do
    now = DateTime.utc_now(:second)

    {count, _rows} =
      Repo.insert_all(
        StripeEvent,
        [
          %{
            id: Ecto.UUID.generate(),
            stripe_event_id: event_id,
            type: type,
            processed_at: now,
            payload: event,
            inserted_at: now,
            updated_at: now
          }
        ],
        on_conflict: :nothing,
        conflict_target: :stripe_event_id
      )

    case count do
      0 -> {:ok, :duplicate}
      1 -> {:ok, :inserted}
    end
  end

  defp upsert_customer(attrs) do
    %Customer{user_id: attr_value(attrs, :user_id)}
    |> Customer.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [
          stripe_customer_id: attr_value(attrs, :stripe_customer_id),
          stripe_customer_account_id: attr_value(attrs, :stripe_customer_account_id),
          updated_at: DateTime.utc_now(:second)
        ]
      ],
      conflict_target: :user_id,
      returning: true
    )
  end

  defp upsert_subscription(attrs) do
    %Subscription{billing_customer_id: attr_value(attrs, :billing_customer_id)}
    |> Subscription.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: subscription_conflict_updates(attrs)
      ],
      conflict_target: :billing_customer_id,
      returning: true
    )
  end

  defp subscription_conflict_updates(attrs) do
    [
      stripe_subscription_id: attr_value(attrs, :stripe_subscription_id),
      stripe_customer_id: attr_value(attrs, :stripe_customer_id),
      stripe_customer_account_id: attr_value(attrs, :stripe_customer_account_id),
      status: attr_value(attrs, :status),
      interval: attr_value(attrs, :interval),
      price_id: attr_value(attrs, :price_id),
      current_period_end: attr_value(attrs, :current_period_end),
      trial_end: attr_value(attrs, :trial_end),
      cancel_at: attr_value(attrs, :cancel_at),
      canceled_at: attr_value(attrs, :canceled_at),
      updated_at: DateTime.utc_now(:second)
    ]
  end

  defp handle_event("checkout.session.completed", event) do
    session = event_object(event)
    user_id = session["client_reference_id"] || get_in(session, ["metadata", "user_id"])

    case user_id do
      nil ->
        {:ok, :ignored}

      user_id ->
        with {:ok, _customer} <-
               upsert_customer(%{
                 user_id: user_id,
                 stripe_customer_id: session["customer"],
                 stripe_customer_account_id: session["customer_account"]
               }) do
          {:ok, :processed}
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
        with {:ok, customer} <-
               upsert_customer(%{
                 user_id: user_id,
                 stripe_customer_id: subscription["customer"],
                 stripe_customer_account_id: subscription["customer_account"]
               }),
             {:ok, _subscription} <-
               upsert_subscription(subscription_attrs(subscription, customer.id)) do
          {:ok, :processed}
        end
    end
  end

  defp handle_event(_type, _event), do: {:ok, :ignored}

  defp subscription_attrs(subscription, billing_customer_id) do
    first_item =
      subscription
      |> get_in(["items", "data"])
      |> case do
        items when is_list(items) -> Enum.at(items, 0)
        _items -> nil
      end

    price = get_in(first_item || %{}, ["price"])

    %{
      billing_customer_id: billing_customer_id,
      stripe_subscription_id: subscription["id"],
      stripe_customer_id: subscription["customer"],
      stripe_customer_account_id: subscription["customer_account"],
      status: subscription["status"],
      interval: get_in(price || %{}, ["recurring", "interval"]),
      price_id: (price || %{})["id"],
      current_period_end: unix_to_datetime(subscription["current_period_end"]),
      trial_end: unix_to_datetime(subscription["trial_end"]),
      cancel_at: unix_to_datetime(subscription["cancel_at"]),
      canceled_at: unix_to_datetime(subscription["canceled_at"])
    }
  end

  defp event_object(event), do: get_in(event, ["data", "object"])

  defp attr_value(attrs, key), do: attrs[key] || attrs[Atom.to_string(key)]

  defp unix_to_datetime(nil), do: nil

  defp unix_to_datetime(value) when is_integer(value), do: DateTime.from_unix!(value, :second)
end
