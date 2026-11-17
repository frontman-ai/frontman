defmodule FrontmanServer.E2EOpenAIAuth do
  @moduledoc false

  alias ReqLLM.Error.API.Request
  alias ReqLLM.StreamChunk
  alias ReqLLM.StreamResponse

  @auth_codes ~w(token_revoked token_expired invalid_token invalid_api_key)

  def validate_mode!(mode) when mode in ["read", "refresh_if_needed", "force_refresh"], do: mode

  def validate_mode!(_mode) do
    raise ArgumentError, "E2E_OPENAI_TOKEN_MODE must be read, refresh_if_needed, or force_refresh"
  end

  def refresh_needed?("force_refresh", _expires_at, _now, _threshold), do: true

  def refresh_needed?(_mode, {:ok, expires_at}, now, threshold) do
    DateTime.diff(expires_at, now, :second) <= threshold
  end

  def refresh_needed?(_mode, {:error, _reason}, _now, _threshold), do: true

  def classify(error), do: classify(error, 4)

  def refresh_error({:token_refresh_failed, status, _body}) when status in [400, 401, 403] do
    "Reauthorization required: OpenAI rejected the refresh grant. " <>
      "Reconnect the E2E OpenAI account and replace the credential pair in Actions and Dependabot secrets."
  end

  def refresh_error(_reason) do
    "OpenAI refresh failed. Check provider availability and network access. " <>
      "Do not repeat rotation blindly; check the trusted workflow result first."
  end

  def recovery_message do
    "OpenAI authentication rejected. Run the trusted Refresh E2E OpenAI token workflow " <>
      "on the default branch with force_refresh=true, then start a new E2E run. " <>
      "If refresh or the second preflight rejects authentication, reauthorization is required."
  end

  # Fresh E2E browser sessions select the first available model. E2E seeds only Codex credentials.
  def model_spec do
    providers = Application.fetch_env!(:frontman_server, :providers)
    %{models: [entry | _]} = Keyword.fetch!(providers, :openai_codex)

    case entry do
      {_name, id} -> "openai_codex:#{id}"
      {_name, _id, spec} -> spec
    end
  end

  def preflight(access_token, account_id) do
    {:ok, _apps} = Application.ensure_all_started(:req_llm)

    options = [
      auth_mode: :oauth,
      access_token: access_token,
      chatgpt_account_id: account_id,
      max_retries: 0,
      receive_timeout: 15_000,
      total_timeout: 30_000,
      stream_idle_timeout: 15_000
    ]

    case ReqLLM.stream_text(model_spec(), "Reply only OK.", options) do
      {:ok, response} -> consume(response)
      {:error, reason} -> {:error, classify(reason)}
    end
  rescue
    error -> {:error, classify(error)}
  end

  defp consume(response) do
    response.stream
    |> Stream.take(64)
    |> Enum.reduce_while({:error, :no_content}, fn
      %StreamChunk{type: :content, text: text}, result ->
        case text do
          text when is_binary(text) and text != "" -> {:halt, :ok}
          _ -> {:cont, result}
        end

      %StreamChunk{type: :meta, metadata: %{finish_reason: :error}} = chunk, _result ->
        {:halt, {:error, classify(chunk)}}

      _chunk, result ->
        {:cont, result}
    end)
  rescue
    error -> {:error, classify(error)}
  after
    StreamResponse.close(response)
  end

  defp classify(_error, 0), do: :other
  defp classify(%Request{status: 401}, _depth), do: :auth_rejected

  defp classify(%Request{status: 403, provider_code: code}, _depth)
       when code in @auth_codes,
       do: :auth_rejected

  defp classify(%Request{status: status}, _depth) when is_integer(status), do: :other

  defp classify(
         %StreamChunk{type: :meta, metadata: %{finish_reason: :error, error_code: code}},
         _depth
       )
       when code in @auth_codes,
       do: :auth_rejected

  defp classify(%{cause: cause}, depth) when not is_nil(cause),
    do: classify(cause, depth - 1)

  defp classify({wrapper, cause}, depth) when wrapper in [:error, :http_task_failed],
    do: classify(cause, depth - 1)

  defp classify(_error, _depth), do: :other
end
