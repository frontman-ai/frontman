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
      Repo.transact(fn ->
        case insert_event(Repo, event_id, type, event) do
          {:ok, stripe_event} -> process_stripe_event(Repo, stripe_event, event_id, type, event)
          {:error, reason} -> {:error, reason}
        end
      end)
      |> normalize_process_result()

    log_event_result(event_id, type, result)

    result
  end

  defp process_stripe_event(_repo, :duplicate, _event_id, _type, _event), do: {:ok, :duplicate}

  defp process_stripe_event(repo, :inserted, event_id, type, event) do
    process_inserted_event(repo, event_id, type, event)
  end

  defp process_inserted_event(repo, event_id, type, event) do
    Logger.info("stripe webhook processing event_id=#{event_id} type=#{type}")

    handle_event(repo, type, event)
  end

  defp normalize_process_result({:ok, {:processed, user_id}}) do
    :ok = FrontmanServer.Billing.broadcast_status_changed(user_id)
    {:ok, :processed}
  end

  defp normalize_process_result({:ok, result}), do: {:ok, result}

  defp normalize_process_result({:error, reason}), do: {:error, reason}

  defp log_event_result(event_id, type, {:ok, result}) do
    Logger.info("stripe webhook #{result} event_id=#{event_id} type=#{type}")
  end

  defp log_event_result(event_id, type, {:error, reason}) do
    Logger.warning(
      "stripe webhook failed event_id=#{event_id} type=#{type} reason=#{inspect(reason)}"
    )
  end

  defp insert_event(repo, event_id, type, event) do
    %StripeEvent{}
    |> StripeEvent.changeset(%{stripe_event_id: event_id, type: type, payload: event})
    # Unique constraint violations abort PostgreSQL transactions without a savepoint.
    |> repo.insert(mode: :savepoint)
    |> case do
      {:ok, _stripe_event} ->
        {:ok, :inserted}

      {:error, changeset} ->
        case unique_constraint_error?(changeset, :stripe_event_id) do
          true -> {:ok, :duplicate}
          false -> {:error, changeset}
        end
    end
  end

  defp unique_constraint_error?(%Ecto.Changeset{errors: errors}, field) do
    errors
    |> Keyword.get_values(field)
    |> Enum.any?(fn {_message, opts} -> opts[:constraint] == :unique end)
  end

  defp upsert_customer(repo, user_id, stripe_customer_id) do
    %Customer{user_id: user_id}
    |> Customer.changeset(%{stripe_customer_id: stripe_customer_id})
    |> repo.insert(
      on_conflict: [
        set: [
          stripe_customer_id: stripe_customer_id,
          updated_at: DateTime.utc_now(:second)
        ]
      ],
      conflict_target: :user_id,
      returning: true
    )
  end

  defp upsert_subscription(repo, billing_customer_id, attrs) do
    %Subscription{billing_customer_id: billing_customer_id}
    |> Subscription.changeset(attrs)
    |> repo.insert(
      on_conflict: [
        set: subscription_conflict_updates(attrs)
      ],
      conflict_target: :billing_customer_id,
      returning: true
    )
  end

  defp subscription_conflict_updates(attrs) do
    attrs
    |> Map.to_list()
    |> Keyword.put(:updated_at, DateTime.utc_now(:second))
  end

  defp handle_event(repo, "checkout.session.completed", event) do
    session = event_object(event)
    user_id = session["client_reference_id"] || get_in(session, ["metadata", "user_id"])

    case user_id do
      nil ->
        {:ok, :ignored}

      user_id ->
        with {:ok, _customer} <-
               upsert_customer(repo, user_id, session["customer"]) do
          {:ok, {:processed, user_id}}
        end
    end
  end

  defp handle_event(repo, "customer.subscription." <> action, event)
       when action in ["created", "updated", "deleted", "paused", "resumed"] do
    subscription = event_object(event)
    user_id = get_in(subscription, ["metadata", "user_id"])

    case user_id do
      nil ->
        {:ok, :ignored}

      user_id ->
        with {:ok, customer} <-
               upsert_customer(repo, user_id, subscription["customer"]),
             {:ok, _subscription} <-
               upsert_subscription(repo, customer.id, subscription_attrs(subscription)) do
          {:ok, {:processed, user_id}}
        end
    end
  end

  defp handle_event(_repo, _type, _event), do: {:ok, :ignored}

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
