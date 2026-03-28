defmodule FrontmanServer.Tools.WebFetch do
  @moduledoc """
  Fetches web page content and returns it as markdown.

  Complements WebSearch (which finds URLs) by retrieving and processing
  content from known URLs. Supports line-based pagination for large pages.
  """

  @behaviour FrontmanServer.Tools.Backend

  @chrome_ua "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
  @honest_ua "Frontman/1.0 (+https://frontman.ai)"
  @max_response_bytes 5_242_880

  @impl true
  def name, do: "web_fetch"

  @impl true
  def description do
    """
    Fetch a web page and return its content as markdown.

    Use this to retrieve content from a known URL. HTML pages are automatically
    converted to markdown. Results are paginated by lines — use offset and limit
    to read through large pages.

    If total_lines > start_line + lines_returned, there is more content available.
    Call again with a higher offset to continue reading.
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "url" => %{
          "type" => "string",
          "description" => "The URL to fetch. Must start with http:// or https://"
        },
        "offset" => %{
          "type" => "integer",
          "description" => "Line number to start from (0-indexed). Default: 0",
          "default" => 0
        },
        "limit" => %{
          "type" => "integer",
          "description" => "Maximum number of lines to return (1-2000). Default: 500",
          "default" => 500
        }
      },
      "required" => ["url"]
    }
  end

  @impl true
  def execute(args, _context) do
    with {:ok, url} <- validate_url(args) do
      offset = clamp(Map.get(args, "offset", 0), 0, :infinity)
      limit = clamp(Map.get(args, "limit", 500), 1, 2000)

      case fetch_url(url) do
        {:ok, content_type, body} ->
          markdown = convert_to_markdown(body, content_type)
          paginate(markdown, url, content_type, offset, limit)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_url(url) do
    case do_fetch(url, @chrome_ua) do
      {:cloudflare_challenge} ->
        case do_fetch(url, @honest_ua) do
          {:cloudflare_challenge} -> {:error, "Blocked by Cloudflare challenge"}
          other -> other
        end

      other ->
        other
    end
  end

  @max_redirects 10

  defp do_fetch(url, user_agent), do: do_fetch(url, user_agent, 0)

  defp do_fetch(_url, _user_agent, redirects) when redirects > @max_redirects do
    {:error, "Too many redirects"}
  end

  defp do_fetch(url, user_agent, redirects) do
    headers = [
      {"accept", "text/markdown, text/html;q=0.9, text/plain;q=0.8"},
      {"user-agent", user_agent}
    ]

    req_opts = [url: url, headers: headers, receive_timeout: 30_000, retry: false, decode_body: false, redirect: false] ++ req_options()

    case Req.get(req_opts) do
      {:ok, %Req.Response{status: status, headers: resp_headers}}
      when status in [301, 302, 303, 307, 308] ->
        follow_redirect(resp_headers, user_agent, redirects)

      {:ok, %Req.Response{status: 403, headers: resp_headers}} ->
        if cloudflare_challenge?(resp_headers) do
          {:cloudflare_challenge}
        else
          {:error, "HTTP 403"}
        end

      {:ok, %Req.Response{status: status, body: body, headers: resp_headers}}
      when status in 200..299 ->
        if byte_size(body) > @max_response_bytes do
          {:error, "Response too large (>5MB)"}
        else
          content_type = get_content_type(resp_headers)
          {:ok, content_type, body}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, "Request timed out"}

      {:error, reason} ->
        {:error, "Failed to fetch: #{inspect(reason)}"}
    end
  end

  defp follow_redirect(resp_headers, user_agent, redirects) do
    case Map.get(resp_headers, "location") do
      [location | _] ->
        with {:ok, host} <- extract_host(location),
             :ok <- validate_host(host) do
          do_fetch(location, user_agent, redirects + 1)
        end

      _ ->
        {:error, "Redirect without Location header"}
    end
  end

  defp cloudflare_challenge?(headers) do
    headers
    |> Map.get("cf-mitigated", [])
    |> Enum.any?(&String.contains?(&1, "challenge"))
  end

  defp get_content_type(headers) do
    case Map.get(headers, "content-type") do
      [value | _] -> value
      nil -> "text/html"
    end
  end

  defp convert_to_markdown(body, content_type) do
    if String.contains?(content_type, "text/html") do
      Html2Markdown.convert(body)
    else
      body
    end
  end

  defp paginate(content, url, content_type, offset, limit) do
    lines = String.split(content, "\n")
    total = length(lines)
    sliced = lines |> Enum.drop(offset) |> Enum.take(limit)

    {:ok,
     %{
       "content" => Enum.join(sliced, "\n"),
       "url" => url,
       "content_type" => content_type,
       "start_line" => offset,
       "lines_returned" => length(sliced),
       "total_lines" => total
     }}
  end

  defp validate_url(%{"url" => url}) when is_binary(url) and byte_size(url) > 0 do
    with :ok <- validate_scheme(url),
         {:ok, host} <- extract_host(url),
         :ok <- validate_host(host) do
      {:ok, url}
    end
  end

  defp validate_url(_), do: {:error, "url is required"}

  defp validate_scheme(url) do
    if String.starts_with?(url, "http://") or String.starts_with?(url, "https://") do
      :ok
    else
      {:error, "URL must start with http:// or https://"}
    end
  end

  defp extract_host(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and byte_size(host) > 0 ->
        {:ok, host}

      _ ->
        {:error, "Could not parse host from URL"}
    end
  end

  defp validate_host(host) do
    # Check for well-known private hostnames before DNS resolution
    if private_hostname?(host) do
      {:error, "Requests to private/internal addresses are not allowed"}
    else
      case resolve_and_check(host) do
        :ok -> :ok
        {:error, _} = err -> err
      end
    end
  end

  defp private_hostname?(host) do
    downcased = String.downcase(host)
    downcased == "localhost" or String.ends_with?(downcased, ".local") or
      String.ends_with?(downcased, ".internal") or String.ends_with?(downcased, ".localhost")
  end

  defp resolve_and_check(host) do
    # Try to parse as a literal IP first, then fall back to DNS resolution
    host_charlist = String.to_charlist(host)

    case :inet.parse_address(host_charlist) do
      {:ok, ip} ->
        if private_ip?(ip),
          do: {:error, "Requests to private/internal addresses are not allowed"},
          else: :ok

      {:error, :einval} ->
        # Not a literal IP — resolve via DNS
        case :inet.getaddrs(host_charlist, :inet) do
          {:ok, addrs} ->
            if Enum.any?(addrs, &private_ip?/1),
              do: {:error, "Requests to private/internal addresses are not allowed"},
              else: :ok

          {:error, _} ->
            # Also try IPv6
            case :inet.getaddrs(host_charlist, :inet6) do
              {:ok, addrs} ->
                if Enum.any?(addrs, &private_ip?/1),
                  do: {:error, "Requests to private/internal addresses are not allowed"},
                  else: :ok

              {:error, _} ->
                # DNS resolution failed — let Req handle the error downstream
                :ok
            end
        end
    end
  end

  # IPv4 private/reserved ranges
  defp private_ip?({0, _, _, _}), do: true
  defp private_ip?({10, _, _, _}), do: true
  defp private_ip?({127, _, _, _}), do: true
  defp private_ip?({169, 254, _, _}), do: true
  defp private_ip?({172, b, _, _}) when b >= 16 and b <= 31, do: true
  defp private_ip?({192, 168, _, _}), do: true

  # IPv6 loopback and private
  defp private_ip?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  defp private_ip?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp private_ip?({0xFC00, _, _, _, _, _, _, _}), do: true
  defp private_ip?({0xFD00, _, _, _, _, _, _, _}), do: true
  defp private_ip?({0xFE80, _, _, _, _, _, _, _}), do: true

  defp private_ip?(_), do: false

  defp clamp(val, min, :infinity) when is_integer(val), do: max(val, min)
  defp clamp(val, min, max_val) when is_integer(val), do: val |> max(min) |> min(max_val)
  defp clamp(_, min, _), do: min

  # Extra Req options — overridden in tests to inject Req.Test as the adapter.
  defp req_options do
    Application.get_env(:frontman_server, :web_fetch_req_options, [])
  end
end
