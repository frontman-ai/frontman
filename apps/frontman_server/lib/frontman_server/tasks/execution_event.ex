defmodule FrontmanServer.Tasks.ExecutionEvent do
  @moduledoc """
  Domain event emitted during task execution.

  Wraps raw SwarmAi runtime events with causation context — which user
  interaction triggered this execution. The SwarmDispatcher acts as an
  Anti-Corruption Layer, translating infrastructure events into these
  domain events before broadcasting on PubSub.
  """

  alias FrontmanServer.Tasks.Execution.LLMError
  alias FrontmanServer.Tasks.StreamStallTimeout

  @type interaction_id :: String.t()

  @type event_type ::
          :chunk
          | :response
          | :tool_call
          | :completed
          | :failed
          | :crashed
          | :cancelled
          | :terminated
          | :paused

  @enforce_keys [:type]
  defstruct [:type, :payload, :caused_by]

  @type t :: %__MODULE__{
          type: event_type(),
          payload: term(),
          caused_by: interaction_id() | nil
        }

  @doc """
  Classifies an execution event into a channel action.

  Persistence is handled by SwarmDispatcher — this function only determines
  what the channel should do in response.
  """
  @spec classify(t()) :: term()
  def classify(%__MODULE__{type: :response}), do: :ok
  def classify(%__MODULE__{type: :completed}), do: :agent_completed
  def classify(%__MODULE__{type: :cancelled}), do: :agent_cancelled
  def classify(%__MODULE__{type: :terminated}), do: :agent_cancelled
  def classify(%__MODULE__{type: :paused}), do: :agent_paused
  def classify(%__MODULE__{type: :tool_call}), do: :ok

  def classify(%__MODULE__{type: :failed, payload: {:error, reason, _loop_id}}) do
    {msg, category, retryable} = classify_error(reason)
    {:agent_error, %{message: msg, category: category, retryable: retryable}}
  end

  def classify(%__MODULE__{type: :crashed, payload: %{reason: reason}}) do
    msg = humanize_crash(reason)
    {:agent_error, %{message: msg, category: "unknown", retryable: false}}
  end

  @doc """
  Classifies an error reason into `{message, category, retryable}`.

  `category` is one of: "auth", "billing", "rate_limit", "overload",
  "payload_too_large", "output_truncated", "unknown".
  """
  @spec classify_error(term()) :: {String.t(), String.t(), boolean()}
  def classify_error(%LLMError{message: msg, category: cat, retryable: r}), do: {msg, cat, r}

  def classify_error(%ReqLLM.Error.API.Stream{cause: %ReqLLM.Error.API.Request{} = cause}) do
    classify_reqllm_request(cause.status, cause.reason)
  end

  def classify_error(%ReqLLM.Error.API.Stream{reason: reason}) when is_binary(reason) do
    classify_reqllm_request(nil, reason)
  end

  def classify_error(%ReqLLM.Error.API.Request{status: status, reason: reason}) do
    classify_reqllm_request(status, reason)
  end

  def classify_error(%StreamStallTimeout.Error{}) do
    {"The AI provider stopped responding mid-reply. " <>
       "This usually happens when the provider is temporarily overloaded. " <>
       "Try sending your message again.", "overload", true}
  end

  def classify_error(:genserver_call_timeout) do
    {"The request to the AI provider timed out. " <>
       "This can happen during high traffic. Try again in a moment.", "overload", true}
  end

  def classify_error(:stream_timeout) do
    {"The request to the AI provider timed out. " <>
       "This can happen during high traffic. Try again in a moment.", "overload", true}
  end

  def classify_error(:output_truncated) do
    {"The AI response was too long and got cut off. " <>
       "This usually happens when writing large files. " <>
       "Try asking the AI to write the file in smaller sections.", "output_truncated", false}
  end

  def classify_error({:exit, reason}) do
    {"Something went wrong while communicating with the AI provider: #{inspect(reason)}",
     "unknown", false}
  end

  def classify_error(reason) when is_exception(reason),
    do: {Exception.message(reason), "unknown", false}

  def classify_error(reason) when is_binary(reason), do: {reason, "unknown", false}
  def classify_error(reason), do: {inspect(reason), "unknown", false}

  defp classify_reqllm_request(status, _reason) when status in [401, 403] do
    {"Authentication failed — your API key may be invalid or expired (HTTP #{status})", "auth",
     false}
  end

  defp classify_reqllm_request(400, reason) when is_binary(reason) do
    {"Bad request — the provider rejected the request: #{reason}", "unknown", false}
  end

  defp classify_reqllm_request(400, _reason) do
    {"Bad request — the provider rejected the request.", "unknown", false}
  end

  defp classify_reqllm_request(402, _reason) do
    {"Payment required — your account balance is insufficient or billing is not configured (HTTP 402)",
     "billing", false}
  end

  defp classify_reqllm_request(413, _reason) do
    {"Payload too large — the request exceeded the provider's size limit. Try reducing image size or message length (HTTP 413)",
     "payload_too_large", false}
  end

  defp classify_reqllm_request(429, _reason) do
    {"Rate limited — the provider is throttling requests. Please try again shortly.",
     "rate_limit", true}
  end

  defp classify_reqllm_request(status, _reason) when is_integer(status) and status >= 500 do
    {"Provider error — the LLM service returned an internal error (HTTP #{status}). Please try again.",
     "overload", true}
  end

  defp classify_reqllm_request(status, reason)
       when is_integer(status) and is_binary(reason) do
    {"LLM error (HTTP #{status}): #{reason}", "unknown", false}
  end

  defp classify_reqllm_request(_status, reason) when is_binary(reason) do
    {"LLM stream error: #{reason}", "unknown", false}
  end

  defp classify_reqllm_request(_status, _reason) do
    {"LLM stream error", "unknown", false}
  end

  # Translates internal error reasons into user-friendly messages.
  defp humanize_error(reason) do
    {message, _category, _retryable} = classify_error(reason)
    message
  end

  # Like humanize_error, but prefixes unknown/fallback reasons with crash context.
  defp humanize_crash(reason) when is_exception(reason), do: humanize_error(reason)
  defp humanize_crash(reason) when is_atom(reason), do: "Execution crashed: #{inspect(reason)}"
  defp humanize_crash(reason), do: "Execution crashed: #{humanize_error(reason)}"
end
