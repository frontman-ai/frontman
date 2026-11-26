defmodule FrontmanServer.Analytics do
  @moduledoc """
  Funnel events. Disabled unless explicitly enabled by the host.

  Admission is a bounded local database write; external delivery runs in Oban.
  Anonymous attempts require a separate opt-in. Browser views require a signed
  receipt acknowledged by the visible hosted page; renders alone emit nothing.
  """

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Analytics.MCPActivation
  alias FrontmanServer.Repo
  alias FrontmanServer.Workers.DeliverHeapEvent

  require Logger

  @browser_events ~w(auth_screen_viewed mcp_checkpoint_viewed billing_setup_viewed)
  @events ~w(mcp_connection_started auth_started auth_completed auth_failed signup_completed
    mcp_access_evaluated mcp_access_rechecked mcp_account_switch_requested
    mcp_authorization_submitted mcp_authorization_completed mcp_authorization_failed
    mcp_connection_expired mcp_client_connected mcp_tools_list_completed
    mcp_initialize_received mcp_initialize_completed mcp_authentication_failed
    mcp_sites_list_completed mcp_tool_call_completed mcp_activated checkout_started checkout_returned
    subscription_access_changed site_connection_started site_connection_completed
    site_connection_failed)
  @properties ~w(entry_surface mcp_client auth_provider framework outcome reason_code
    is_new_user access_status previous_access_status subscription_status tool_name
    count duration_ms request_id interval onboarding_attempt_id activation_scope operation_kind
    identity_kind transport mcp_connection_id mcp_client_key)

  @doc "Queues an allowlisted event; analytics errors never interrupt the caller."
  def track(event, properties) when is_binary(event) and is_map(properties) do
    with true <- config()[:enabled] == true,
         true <- event in (@events ++ @browser_events),
         {:ok, identity} <- identity(event, properties),
         {:ok, args} <- envelope(event, identity, properties) do
      enqueue(args)
    else
      false -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    _exception -> failure(:enqueue_exception)
  catch
    :exit, _reason -> failure(:enqueue_unavailable)
  end

  @doc """
  Records first successful WordPress use, once per user and authenticated client.

  The permanent unique rows, not Oban retention, define first use. Milestones and
  their delivery jobs commit together. A failed analytics transaction leaves the
  operation successful and allows a later successful operation to retry admission.
  Collection disabled at operation time does not record or backfill milestones.
  """
  def record_mcp_activation(%Scope{} = scope, client_id, properties) when is_map(properties) do
    if config()[:enabled] == true do
      scope
      |> activation_rows(client_id)
      |> persist_activation(properties)
    else
      :ok
    end
  rescue
    _exception -> failure(:activation_exception)
  catch
    :exit, _reason -> failure(:activation_unavailable)
  end

  @doc false
  def config, do: Application.get_env(:frontman_server, __MODULE__, [])

  def browser_event?(event), do: event in @browser_events

  # Oban's uniqueness transaction does not forward its insert timeout to checkout.
  # Fail immediately on pool saturation instead of delaying the user's request.
  defp enqueue(args) do
    result =
      Repo.transaction(fn -> args |> DeliverHeapEvent.new() |> Oban.insert(timeout: 500) end,
        timeout: 500,
        queue: false
      )

    case result do
      {:ok, {:ok, _job}} -> :ok
      {:ok, {:error, _changeset}} -> failure(:enqueue_failed)
      {:error, _reason} -> failure(:enqueue_failed)
    end
  end

  defp activation_rows(scope, client_id) do
    Enum.map(activation_keys(client_id), fn key ->
      %{
        user_id: Scope.user_id(scope),
        client_key: key,
        event_id: Ecto.UUID.generate(),
        inserted_at: DateTime.utc_now()
      }
    end)
  end

  defp activation_keys(client_id) when is_binary(client_id) and byte_size(client_id) > 0 do
    ["", :crypto.hash(:sha256, client_id) |> Base.encode16(case: :lower)]
  end

  defp activation_keys(_client_id), do: [""]

  defp persist_activation(rows, properties) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(:milestones, MCPActivation, rows,
      on_conflict: :nothing,
      conflict_target: [:user_id, :client_key],
      returning: true,
      timeout: 500
    )
    |> Ecto.Multi.run(:delivery, fn _repo, %{milestones: {_count, milestones}} ->
      enqueue_activations(milestones, properties)
    end)
    |> Repo.transaction(timeout: 500, queue: false)
    |> case do
      {:ok, _} -> :ok
      {:error, _step, _reason, _changes} -> failure(:activation_enqueue_failed)
    end
  end

  defp enqueue_activations(milestones, properties) do
    Enum.reduce_while(milestones, {:ok, :ok}, fn milestone, _acc ->
      properties =
        Map.merge(properties, %{
          user_id: milestone.user_id,
          event_id: milestone.event_id,
          entry_surface: "mcp",
          outcome: "succeeded",
          activation_scope: if(milestone.client_key == "", do: "user", else: "user_client"),
          mcp_client_key: if(milestone.client_key == "", do: nil, else: milestone.client_key),
          operation_kind: "unknown"
        })

      {:ok, args} = envelope("mcp_activated", milestone.user_id, properties)

      case args |> DeliverHeapEvent.new() |> Oban.insert(timeout: 500) do
        {:ok, _job} -> {:cont, {:ok, :ok}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp identity("mcp_authentication_failed", properties) do
    with true <- config()[:anonymous_enabled] == true,
         {:ok, bucket} <- Ecto.UUID.cast(value(properties, "diagnostic_bucket_id")) do
      {:ok, "mcp_diagnostic:" <> bucket}
    else
      _ -> {:error, :identity_unavailable}
    end
  end

  defp identity(_event, properties) do
    case Ecto.UUID.cast(value(properties, "user_id")) do
      {:ok, user_id} -> {:ok, user_id}
      :error -> anonymous_identity(properties)
    end
  end

  defp anonymous_identity(properties) do
    with true <- config()[:anonymous_enabled] == true,
         {:ok, attempt} <- Ecto.UUID.cast(value(properties, "onboarding_attempt_id")) do
      {:ok, "onboarding:" <> attempt}
    else
      _ -> {:error, :identity_unavailable}
    end
  end

  defp envelope(event, identity, properties) do
    event_id = value(properties, "event_id") || Ecto.UUID.generate()

    case Ecto.UUID.cast(event_id) do
      {:ok, event_id} ->
        build_envelope(event, identity, properties, event_id)

      :error ->
        {:error, :invalid_event_id}
    end
  end

  defp build_envelope(event, identity, properties, event_id) do
    occurred_at = DateTime.utc_now() |> DateTime.to_iso8601()

    safe =
      Enum.reduce(@properties, %{}, fn key, acc ->
        put_safe(acc, key, value(properties, key))
      end)
      |> Map.merge(%{
        "event_id" => event_id,
        "occurred_at" => occurred_at,
        "event_source" => if(browser_event?(event), do: "hosted_browser", else: "server")
      })
      |> put_optional("frontman_user_id", verified_user_id(properties))
      |> put_optional("release_version", config()[:release_version])

    {:ok,
     %{
       event: event,
       identity: identity,
       event_id: event_id,
       timestamp: occurred_at,
       properties: safe
     }}
  end

  defp put_safe(acc, key, value) do
    if safe_value?(value), do: Map.put(acc, key, value), else: acc
  end

  defp value(properties, key) do
    Enum.find_value(properties, fn
      {^key, value} ->
        {:found, value}

      {atom, value} when is_atom(atom) ->
        if Atom.to_string(atom) == key, do: {:found, value}

      _ ->
        nil
    end)
    |> case do
      {:found, value} -> value
      nil -> nil
    end
  end

  defp verified_user_id(properties) do
    case Ecto.UUID.cast(value(properties, "user_id")) do
      {:ok, id} -> id
      :error -> nil
    end
  end

  defp safe_value?(value) when is_boolean(value), do: true
  defp safe_value?(value) when is_number(value), do: true
  defp safe_value?(value) when is_atom(value), do: false

  defp safe_value?(value) when is_binary(value),
    do: byte_size(value) <= 128 and Regex.match?(~r/\A[a-zA-Z0-9_.:-]+\z/, value)

  defp safe_value?(_value), do: false

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)

  defp failure(reason) do
    Logger.warning("Heap analytics unavailable: #{reason}")
    {:error, reason}
  end
end
