defmodule FrontmanServer.E2EChatGPTTokenScript do
  @moduledoc false

  alias FrontmanServer.Providers.ChatGPTOAuth

  @default_threshold_seconds 259_200

  def run do
    mode = System.get_env("E2E_CHATGPT_TOKEN_MODE", "read")
    access_token = required_env!("E2E_CHATGPT_ACCESS_TOKEN")
    refresh_token = required_env!("E2E_CHATGPT_REFRESH_TOKEN")
    account_id = System.get_env("E2E_CHATGPT_ACCOUNT_ID")

    threshold_seconds =
      env_integer("E2E_CHATGPT_REFRESH_THRESHOLD_SECONDS", @default_threshold_seconds)

    now = DateTime.utc_now()

    current_expires_at = token_expires_at(access_token)

    refresh_needed =
      case current_expires_at do
        {:ok, expires_at} -> DateTime.diff(expires_at, now, :second) <= threshold_seconds
        {:error, _reason} -> true
      end

    result =
      case mode do
        "read" ->
          {:ok,
           build_result(
             access_token,
             refresh_token,
             account_id,
             current_expires_at,
             refresh_needed,
             false,
             now
           )}

        "refresh_if_needed" ->
          maybe_refresh_if_needed(
            access_token,
            refresh_token,
            account_id,
            current_expires_at,
            refresh_needed,
            now
          )

        other ->
          {:error, {:invalid_mode, other}}
      end

    case result do
      {:ok, token_result} ->
        mask_secrets(token_result)
        write_github_output(token_result)
        print_summary(mode, token_result)

      {:error, reason} ->
        IO.puts(:stderr, "[e2e-chatgpt-token] failed: #{format_error(reason)}")
        System.halt(1)
    end
  end

  defp maybe_refresh_if_needed(
         access_token,
         refresh_token,
         account_id,
         current_expires_at,
         refresh_needed,
         now
       ) do
    if refresh_needed do
      ensure_req_started!()

      case ChatGPTOAuth.refresh_token(refresh_token) do
        {:ok, refreshed_tokens} ->
          refreshed_access_token = refreshed_tokens.access_token
          refreshed_refresh_token = refreshed_tokens.refresh_token || refresh_token

          refreshed_expires_at =
            case token_expires_at(refreshed_access_token) do
              {:ok, expires_at} ->
                {:ok, expires_at}

              {:error, _reason} ->
                expires_at_from_expires_in(refreshed_tokens.expires_in, now)
            end

          refreshed_account_id =
            extract_account_id_from_tokens(refreshed_access_token, refreshed_tokens.id_token) ||
              account_id

          {:ok,
           build_result(
             refreshed_access_token,
             refreshed_refresh_token,
             refreshed_account_id,
             refreshed_expires_at,
             true,
             true,
             now
           )}

        {:error, reason} ->
          {:error, {:refresh_failed, reason}}
      end
    else
      {:ok,
       build_result(
         access_token,
         refresh_token,
         account_id,
         current_expires_at,
         false,
         false,
         now
       )}
    end
  end

  defp build_result(
         access_token,
         refresh_token,
         account_id,
         expires_at_result,
         refresh_needed,
         rotated,
         now
       ) do
    resolved_account_id = account_id || extract_account_id(access_token)
    expires_at = expires_at_value(expires_at_result)

    %{
      access_token: access_token,
      refresh_token: refresh_token,
      account_id: resolved_account_id,
      expires_at: expires_at,
      expires_in_seconds: expires_in_seconds(expires_at, now),
      refresh_needed: refresh_needed,
      rotated: rotated
    }
  end

  defp expires_at_value({:ok, expires_at}), do: expires_at
  defp expires_at_value({:error, _reason}), do: nil

  defp expires_in_seconds(nil, _now), do: nil
  defp expires_in_seconds(expires_at, now), do: DateTime.diff(expires_at, now, :second)

  defp required_env!(name) do
    case System.get_env(name) do
      value when is_binary(value) and value != "" -> value
      _ -> raise "Missing required environment variable #{name}"
    end
  end

  defp env_integer(name, default) do
    case System.get_env(name) do
      nil ->
        default

      value ->
        case Integer.parse(value) do
          {integer, ""} -> integer
          _ -> raise "Invalid integer value for #{name}: #{inspect(value)}"
        end
    end
  end

  defp ensure_req_started! do
    case Application.ensure_all_started(:req) do
      {:ok, _apps} -> :ok
      {:error, reason} -> raise "Failed to start Req: #{inspect(reason)}"
    end
  end

  defp extract_account_id(access_token) do
    case ChatGPTOAuth.extract_account_id(access_token) do
      {:ok, account_id} -> account_id
      {:error, _reason} -> nil
    end
  end

  defp extract_account_id_from_tokens(access_token, id_token) do
    ChatGPTOAuth.extract_account_id_from_tokens(%{
      access_token: access_token,
      id_token: id_token || ""
    })
  end

  defp expires_at_from_expires_in(expires_in, now) when is_integer(expires_in) do
    {:ok, now |> DateTime.add(expires_in, :second) |> DateTime.truncate(:second)}
  end

  defp expires_at_from_expires_in(_expires_in, _now), do: {:error, :missing_expiration}

  defp token_expires_at(token) do
    with {:ok, claims} <- decode_jwt_payload(token),
         exp when is_integer(exp) <- claims["exp"],
         {:ok, expires_at} <- DateTime.from_unix(exp, :second) do
      {:ok, DateTime.truncate(expires_at, :second)}
    else
      nil -> {:error, :missing_exp}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected_exp, other}}
    end
  end

  defp decode_jwt_payload(jwt) do
    case String.split(jwt, ".") do
      [_header, payload, _signature] ->
        case Base.url_decode64(pad_base64url(payload), padding: false) do
          {:ok, json} -> Jason.decode(json)
          :error -> {:error, :invalid_base64}
        end

      _ ->
        {:error, :invalid_jwt}
    end
  end

  defp pad_base64url(str) do
    case rem(byte_size(str), 4) do
      2 -> str <> "=="
      3 -> str <> "="
      _ -> str
    end
  end

  defp mask_secrets(token_result) do
    Enum.each([token_result.access_token, token_result.refresh_token], fn value ->
      IO.puts("::add-mask::#{value}")
    end)

    case token_result.account_id do
      value when is_binary(value) and value != "" -> IO.puts("::add-mask::#{value}")
      _ -> :ok
    end
  end

  defp write_github_output(token_result) do
    case System.get_env("GITHUB_OUTPUT") do
      nil -> :ok
      output_path -> write_outputs(output_path, token_result)
    end
  end

  defp write_outputs(output_path, token_result) do
    output_lines = [
      output_line("access_token", token_result.access_token),
      output_line("refresh_token", token_result.refresh_token),
      output_line("account_id", token_result.account_id || ""),
      output_line("expires_at", format_datetime(token_result.expires_at)),
      output_line("expires_in_seconds", format_integer(token_result.expires_in_seconds)),
      output_line("refresh_needed", to_string(token_result.refresh_needed)),
      output_line("rotated", to_string(token_result.rotated))
    ]

    File.write!(output_path, output_lines, [:append])
  end

  defp output_line(name, value), do: "#{name}=#{value}\n"

  defp format_datetime(nil), do: ""
  defp format_datetime(datetime), do: DateTime.to_iso8601(datetime)

  defp format_integer(nil), do: ""
  defp format_integer(value), do: Integer.to_string(value)

  defp print_summary(mode, token_result) do
    IO.puts("[e2e-chatgpt-token] mode=#{mode}")
    IO.puts("[e2e-chatgpt-token] rotated=#{token_result.rotated}")
    IO.puts("[e2e-chatgpt-token] refresh_needed=#{token_result.refresh_needed}")

    case token_result.expires_at do
      %DateTime{} = expires_at ->
        IO.puts("[e2e-chatgpt-token] expires_at=#{DateTime.to_iso8601(expires_at)}")

      nil ->
        IO.puts("[e2e-chatgpt-token] expires_at=unknown")
    end

    case token_result.expires_in_seconds do
      value when is_integer(value) ->
        IO.puts("[e2e-chatgpt-token] expires_in_seconds=#{value}")

      nil ->
        IO.puts("[e2e-chatgpt-token] expires_in_seconds=unknown")
    end

    IO.puts(
      "[e2e-chatgpt-token] account_id_present=#{is_binary(token_result.account_id) and token_result.account_id != ""}"
    )
  end

  defp format_error({:invalid_mode, mode}) do
    "invalid mode #{inspect(mode)} (expected \"read\" or \"refresh_if_needed\")"
  end

  defp format_error({:refresh_failed, reason}) do
    "token refresh failed: #{inspect(reason)}"
  end

  defp format_error(reason), do: inspect(reason)
end

FrontmanServer.E2EChatGPTTokenScript.run()
