defmodule FrontmanServer.ResendClient do
  @moduledoc """
  Resend contact writes and one-shot activation entry requests.
  Workers own retries and decide when failures require operator review.
  """

  alias FrontmanServer.Accounts.User

  def create_contact(%User{} = user, properties \\ %{}) do
    mailer = mailer()

    request(
      :post,
      mailer[:contacts_url],
      %{
        email: user.email,
        first_name: first_name(user.name),
        segments: [%{id: mailer[:segment_id]}]
      }
      |> Map.merge(properties)
    )
    |> contact_result()
  end

  def update_properties(%User{} = user, properties) do
    case request(:patch, mailer()[:contacts_url] <> "/" <> URI.encode_www_form(user.email), %{
           properties: properties
         }) do
      {:ok, %Req.Response{status: 404}} ->
        create_contact(user, %{properties: properties})

      response ->
        contact_result(response)
    end
  end

  def send_activation_entry(%User{} = user) do
    case request(:post, "https://api.resend.com/events/send", %{
           event: "frontman.activation.entered",
           email: user.email
         }) do
      {:ok, %Req.Response{status: 202}} -> :ok
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, _reason} -> {:error, :transport_uncertain}
    end
  end

  def report_failure(job, reason, mode) when mode in [:entry, :exit] do
    {category, status} = failure(reason)
    Sentry.Context.clear_all()

    Sentry.capture_message(
      if(mode == :entry,
        do: "Activation entry failed or uncertain",
        else: "Activation exit failed"
      ),
      level: :error,
      tags: %{error_type: "activation_#{mode}"},
      extra: %{
        failure_category: category,
        status: status,
        user_id: job.args["user_id"],
        job_id: job.id
      }
    )
  end

  defp request(method, url, payload) do
    options = Application.get_env(:frontman_server, __MODULE__, [])[:req_options] || []

    Req.request(
      Keyword.merge(options,
        method: method,
        url: url,
        json: payload,
        headers: [{"authorization", "Bearer #{mailer()[:api_key]}"}],
        retry: false,
        redirect: false,
        receive_timeout: 15_000,
        connect_options: [timeout: 5_000]
      )
    )
  end

  defp contact_result({:ok, %Req.Response{status: status}}) when status in 200..299,
    do: :ok

  defp contact_result({:ok, %Req.Response{status: status}}), do: {:error, {:http_status, status}}
  defp contact_result({:error, reason}), do: {:error, reason}

  defp failure({:http_status, status}) when is_integer(status), do: {"http_error", status}
  defp failure(%Req.TransportError{}), do: {"transport_uncertain", nil}

  defp failure(reason)
       when reason in [:transport_uncertain, :exception, :replay_refused, :coordination_failed],
       do: {Atom.to_string(reason), nil}

  defp failure(_reason), do: {"contact_sync_failed", nil}

  defp mailer, do: Application.fetch_env!(:frontman_server, FrontmanServer.Mailer)
  defp first_name(nil), do: nil
  defp first_name(name), do: name |> String.split(" ", parts: 2) |> List.first()
end
