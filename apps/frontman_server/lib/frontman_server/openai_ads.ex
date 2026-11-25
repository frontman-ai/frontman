defmodule FrontmanServer.OpenAIAds do
  @moduledoc "Consent and durable, per-user advertising delivery bookkeeping."
  import Ecto.Changeset
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.OpenAIAds.{Consent, DeliverConversion, Delivery}
  alias FrontmanServer.Repo

  def enabled?, do: Application.get_env(:frontman_server, __MODULE__, [])[:enabled] == true

  def grant(
        %Scope{} = scope,
        id,
        %{"advertising_consent" => true, "oppref" => oppref, "consent_updated_at_ms" => choice}
      )
      when (is_nil(oppref) or (is_binary(oppref) and byte_size(oppref) in 1..2048)) and
             is_integer(choice) do
    user_id = user_id(scope)

    Repo.transaction(fn ->
      lock_user(user_id)
      consent = get_consent(id)
      consent = if owned?(consent, user_id), do: consent, else: nil
      now_ms = System.system_time(:millisecond)

      unless choice in (now_ms - 180 * 86_400_000)..(now_ms + 600_000),
        do: Repo.rollback(:invalid_consent)

      active? = active?(consent)
      row = if active?, do: consent, else: %Consent{}

      attrs =
        case {active?, oppref} do
          {true, nil} ->
            %{}

          _new_attribution ->
            %{
              oppref: oppref,
              granted_at: DateTime.utc_now(),
              expires_at:
                min(now_ms + 30 * 86_400_000, choice + 180 * 86_400_000)
                |> div(1000)
                |> DateTime.from_unix!()
            }
        end

      row
      |> change(Map.put(attrs, :user_id, user_id))
      |> Repo.insert_or_update!(log: false)
    end)
  end

  def grant(%Scope{}, _id, _params), do: {:error, :invalid_consent}

  def associate(%Scope{}, nil), do: :ok

  def associate(%Scope{user: %{id: user_id}}, id) do
    transact(user_id, fn ->
      consent = get_consent(id)

      if owned?(consent, user_id) && active?(consent) do
        Repo.update!(change(consent, user_id: user_id))
      end
    end)
  end

  def withdraw(%Scope{} = scope, id) do
    user_id = user_id(scope)

    transact(user_id, fn ->
      consent = get_consent(id)
      if is_nil(user_id) || owned?(consent, user_id), do: revoke(consent)

      if user_id do
        Consent.for_user(user_id) |> Repo.all() |> Enum.each(&revoke/1)
      end
    end)
  end

  @doc "Claims a milestone once. First edits require a recorded signup, regardless of its delivery status."
  def record(%Scope{user: %{id: user_id}}, kind, source_ref)
      when kind in ["registration_completed", "first_successful_edit"] do
    transact(user_id, fn ->
      if kind == "registration_completed" or
           Repo.exists?(Delivery.milestone(user_id, "registration_completed")) do
        claim(user_id, kind, source_ref)
      end
    end)
  end

  def active?(%Consent{revoked_at: nil, expires_at: expires_at}),
    do: DateTime.compare(expires_at, DateTime.utc_now()) == :gt

  def active?(_consent), do: false

  defp claim(user_id, kind, source_ref) do
    consent = Repo.one(Consent.latest_for_user(user_id))
    reportable = enabled?() and active?(consent)

    row = %{
      id: Ecto.UUID.generate(),
      user_id: user_id,
      kind: kind,
      source_ref: source_ref,
      timestamp_ms: System.system_time(:millisecond),
      status: if(reportable, do: "pending", else: "suppressed"),
      consent_id: if(reportable, do: consent.id),
      oppref: if(reportable, do: consent.oppref)
    }

    case Repo.insert_all(Delivery, [row],
           on_conflict: :nothing,
           log: false,
           conflict_target: [:user_id, :kind],
           returning: [:id]
         ) do
      {1, [%{id: id}]} when reportable ->
        {:ok, _} = DeliverConversion.new(%{delivery_id: id}) |> Oban.insert()

      _already_consumed_or_denied ->
        :ok
    end
  end

  defp user_id(%Scope{user: nil}), do: nil
  defp user_id(%Scope{user: %{id: id}}), do: id
  defp lock_user(nil), do: :ok
  defp lock_user(id), do: Repo.one!(Consent.user_lock(id))

  defp transact(user_id, action) do
    {:ok, _} =
      Repo.transaction(fn ->
        lock_user(user_id)
        action.()
      end)

    :ok
  end

  defp get_consent(nil), do: nil

  defp get_consent(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Repo.one(Consent.lock_query(id))
      :error -> nil
    end
  end

  defp owned?(nil, _user_id), do: true
  defp owned?(%Consent{user_id: nil}, _user_id), do: true
  defp owned?(%Consent{user_id: owner}, user_id), do: owner == user_id
  defp revoke(nil), do: :ok

  defp revoke(consent) do
    Repo.update!(change(consent, revoked_at: DateTime.utc_now(:second), oppref: nil))

    Delivery.pending_for_consent(consent.id)
    |> Repo.update_all(set: [status: "suppressed", oppref: nil])
  end
end
