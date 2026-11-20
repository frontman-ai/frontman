defmodule FrontmanServer.OpenAIAds.DeliverConversion do
  @moduledoc false
  use Oban.Worker, queue: :default, max_attempts: 12
  import Ecto.Changeset
  alias FrontmanServer.{OpenAIAds, Repo}
  alias FrontmanServer.OpenAIAds.{CAPI, Consent, Delivery}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"delivery_id" => id}}) do
    {:ok, result} =
      Repo.transaction(fn ->
        case Repo.get(Delivery, id) do
          %Delivery{user_id: user_id} ->
            Repo.one!(Consent.user_lock(user_id))
            deliver(Repo.get!(Delivery, id))

          nil ->
            :ok
        end
      end)

    result
  end

  defp deliver(%Delivery{status: "pending"} = delivery) do
    result =
      case Repo.one(Consent.lock_query(delivery.consent_id)) do
        %Consent{user_id: owner} = consent when owner == delivery.user_id ->
          if OpenAIAds.active?(consent), do: CAPI.send(delivery), else: {:discard, :permission}

        _missing ->
          {:discard, :permission}
      end

    case result do
      {:error, _reason} ->
        result

      outcome ->
        status = if outcome == :ok, do: "delivered", else: "suppressed"
        Repo.update!(change(delivery, status: status, oppref: nil))
        outcome
    end
  end

  defp deliver(_consumed), do: :ok
end
