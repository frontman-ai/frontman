defmodule FrontmanServer.Tasks.Execution.ErrorClassifier do
  @moduledoc """
  Classifies execution error reasons for persistence and client retry behavior.
  """

  alias FrontmanServer.Tasks.Execution.LLMError
  alias FrontmanServer.Tasks.StreamStallTimeout

  @auto_retry_threshold_seconds 60

  @doc """
  Classifies an error reason into provider-neutral error info.

  `category` is one of: "auth", "billing", "quota", "rate_limit", "overload",
  "payload_too_large", "output_truncated", "unknown".
  """
  def classify_error(%LLMError{message: msg, category: cat, retryable: r}) do
    error_info(msg, cat, r)
  end

  def classify_error(%ReqLLM.Error.API.Stream{cause: %ReqLLM.Error.API.Request{} = cause}) do
    classify_reqllm_request(cause)
  end

  def classify_error(%ReqLLM.Error.API.Stream{reason: reason}) when is_binary(reason) do
    classify_reqllm_request(nil, reason)
  end

  def classify_error(%ReqLLM.Error.API.Request{} = request) do
    classify_reqllm_request(request)
  end

  def classify_error({:exception, reason}), do: classify_error(reason)

  def classify_error({:llm_error, reason}), do: classify_error(reason)

  def classify_error(:no_api_key),
    do: error_info("No API key available for this request.", "auth", false)

  def classify_error(:missing_model),
    do: error_info("Model is required for this request.", "auth", false)

  def classify_error(:registration_timeout),
    do: error_info("Agent failed to start. Please try again.", "unknown", false)

  def classify_error(%StreamStallTimeout.Error{}) do
    error_info(
      "The AI provider stopped responding mid-reply. " <>
        "This usually happens when the provider is temporarily overloaded. " <>
        "Try sending your message again.",
      "overload",
      true
    )
  end

  def classify_error(:genserver_call_timeout) do
    error_info(
      "The request to the AI provider timed out. " <>
        "This can happen during high traffic. Try again in a moment.",
      "overload",
      true
    )
  end

  def classify_error(:stream_timeout) do
    error_info(
      "The request to the AI provider timed out. " <>
        "This can happen during high traffic. Try again in a moment.",
      "overload",
      true
    )
  end

  def classify_error(:output_truncated) do
    error_info(
      "The AI response was too long and got cut off. " <>
        "This usually happens when writing large files. " <>
        "Try asking the AI to write the file in smaller sections.",
      "output_truncated",
      false
    )
  end

  def classify_error({:exit, reason}) do
    error_info(
      "Something went wrong while communicating with the AI provider: #{inspect(reason)}",
      "unknown",
      false
    )
  end

  def classify_error(reason) when is_exception(reason),
    do: error_info(Exception.message(reason), "unknown", false)

  def classify_error(reason) when is_binary(reason), do: error_info(reason, "unknown", false)
  def classify_error(reason), do: error_info(inspect(reason), "unknown", false)

  defp classify_reqllm_request(%ReqLLM.Error.API.Request{status: 429} = request) do
    retry_available_at = retry_available_at(request)

    case quota_limited?(request) do
      true ->
        error_info(
          "Provider quota reached. Try again after the reset time or configure a different provider.",
          "quota",
          false,
          retry_available_at
        )

      false ->
        rate_limit_error_info(retry_available_at)
    end
  end

  defp classify_reqllm_request(%ReqLLM.Error.API.Request{status: status, reason: reason}) do
    classify_reqllm_request(status, reason)
  end

  defp classify_reqllm_request(status, _reason) when status in [401, 403] do
    error_info(
      "Authentication failed — your API key may be invalid or expired (HTTP #{status})",
      "auth",
      false
    )
  end

  defp classify_reqllm_request(400, reason) when is_binary(reason) do
    error_info("Bad request — the provider rejected the request: #{reason}", "unknown", false)
  end

  defp classify_reqllm_request(400, _reason) do
    error_info("Bad request — the provider rejected the request.", "unknown", false)
  end

  defp classify_reqllm_request(402, _reason) do
    error_info(
      "Payment required — your account balance is insufficient or billing is not configured (HTTP 402)",
      "billing",
      false
    )
  end

  defp classify_reqllm_request(413, _reason) do
    error_info(
      "Payload too large — the request exceeded the provider's size limit. Try reducing image size or message length (HTTP 413)",
      "payload_too_large",
      false
    )
  end

  defp classify_reqllm_request(status, _reason) when is_integer(status) and status >= 500 do
    error_info(
      "Provider error — the LLM service returned an internal error (HTTP #{status}). Please try again.",
      "overload",
      true
    )
  end

  defp classify_reqllm_request(status, reason)
       when is_integer(status) and is_binary(reason) do
    error_info("LLM error (HTTP #{status}): #{reason}", "unknown", false)
  end

  defp classify_reqllm_request(_status, reason) when is_binary(reason) do
    error_info("LLM stream error: #{reason}", "unknown", false)
  end

  defp classify_reqllm_request(_status, _reason) do
    error_info("LLM stream error", "unknown", false)
  end

  defp rate_limit_error_info(retry_available_at) do
    error_info(
      "Rate limited — the provider is throttling requests. Please try again shortly.",
      "rate_limit",
      auto_retryable?(retry_available_at),
      retry_available_at
    )
  end

  defp auto_retryable?(nil), do: true

  defp auto_retryable?(%DateTime{} = retry_available_at) do
    DateTime.diff(retry_available_at, DateTime.utc_now(:second), :second) <=
      @auto_retry_threshold_seconds
  end

  defp error_info(message, category, retryable, retry_available_at \\ nil) do
    %{
      message: message,
      category: category,
      retryable: retryable,
      retry_available_at: retry_available_at
    }
  end

  defp retry_available_at(%ReqLLM.Error.API.Request{} = request) do
    retry_after_available_at(request.headers) ||
      response_body_reset_at(request.response_body) ||
      response_body_rate_limit_reset_at(request.response_body) ||
      reset_header_at(request.headers)
  end

  defp response_body_reset_at(response_body) do
    parse_absolute_time(get_in(response_body || %{}, ["error", "resets_at"])) ||
      retry_at_after_seconds(get_in(response_body || %{}, ["error", "resets_in_seconds"]))
  end

  defp response_body_rate_limit_reset_at(%{"rate_limits" => rate_limits})
       when is_map(rate_limits) do
    Enum.find_value(rate_limits, fn
      {_name, %{"used_percentage" => 100, "resets_at" => resets_at}} ->
        parse_unix_epoch(resets_at)

      _other ->
        nil
    end)
  end

  defp response_body_rate_limit_reset_at(_response_body), do: nil

  defp retry_after_available_at(headers) do
    value = header_value(headers, "retry-after")

    retry_at_after_seconds(value) || parse_http_date(value) || parse_absolute_time(value)
  end

  defp reset_header_at(headers) when is_list(headers) do
    Enum.find_value(headers, fn {name, value} ->
      normalized_name = String.downcase(to_string(name))

      cond do
        String.ends_with?(normalized_name, "reset-at") ->
          parse_absolute_time(value)

        String.ends_with?(normalized_name, "reset-after-seconds") ->
          retry_at_after_seconds(value)

        true ->
          nil
      end
    end)
  end

  defp reset_header_at(_headers), do: nil

  defp header_value(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn {header_name, value} ->
      case String.downcase(to_string(header_name)) == name do
        true -> value
        false -> nil
      end
    end)
  end

  defp header_value(_headers, _name), do: nil

  defp parse_absolute_time(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> DateTime.truncate(datetime, :second)
      {:error, _reason} -> nil
    end
  end

  defp parse_absolute_time(_value), do: nil

  defp parse_unix_epoch(value) when is_integer(value) do
    case DateTime.from_unix(value, :second) do
      {:ok, datetime} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp parse_unix_epoch(_value), do: nil

  defp retry_at_after_seconds(seconds) when is_integer(seconds) do
    case seconds >= 0 do
      true -> DateTime.utc_now(:second) |> DateTime.add(seconds, :second)
      false -> nil
    end
  end

  defp retry_at_after_seconds(value) when is_binary(value) do
    case Integer.parse(value) do
      {seconds, ""} -> retry_at_after_seconds(seconds)
      _not_integer -> nil
    end
  end

  defp retry_at_after_seconds(_value), do: nil

  defp parse_http_date(value) when is_binary(value) do
    value
    |> String.to_charlist()
    |> :httpd_util.convert_request_date()
    |> NaiveDateTime.from_erl!()
    |> DateTime.from_naive!("Etc/UTC")
  rescue
    _bad_http_date -> nil
  end

  defp parse_http_date(_value), do: nil

  defp quota_limited?(%ReqLLM.Error.API.Request{} = request) do
    quota_body?(request.response_body) || quota_headers?(request.headers)
  end

  defp quota_body?(%{"error" => error}) when is_map(error) do
    error["type"] in ["usage_limit_reached", "insufficient_quota"] ||
      error["code"] == "insufficient_quota" || quota_message?(error["message"])
  end

  defp quota_body?(_response_body), do: false

  defp quota_message?(message) when is_binary(message) do
    normalized = String.downcase(message)

    Enum.any?(
      [
        "usage limit",
        "session limit",
        "weekly limit",
        "opus limit"
      ],
      &String.contains?(normalized, &1)
    )
  end

  defp quota_message?(_message), do: false

  defp quota_headers?(headers) when is_list(headers) do
    reset_header_at(headers) != nil &&
      Enum.any?(headers, fn {name, value} ->
        String.ends_with?(String.downcase(to_string(name)), "-used-percent") and
          to_string(value) == "100"
      end)
  end

  defp quota_headers?(_headers), do: false
end
