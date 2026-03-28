defmodule FrontmanServer.Tools.WebFetch do
  @moduledoc """
  Fetches web page content and returns it as markdown.

  Complements WebSearch (which finds URLs) by retrieving and processing
  content from known URLs. Supports line-based pagination for large pages.
  """

  @behaviour FrontmanServer.Tools.Backend

  @chrome_ua "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " <>
               "AppleWebKit/537.36 (KHTML, like Gecko) " <>
               "Chrome/131.0.0.0 Safari/537.36"
  @honest_ua "Frontman/1.0 (+https://frontman.ai)"
  @max_response_bytes 5_242_880
  @max_redirects 10

  @impl true
  @spec name() :: String.t()
  def name, do: "web_fetch"

  @impl true
  @spec description() :: String.t()
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
  @spec parameter_schema() :: map()
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
  @spec execute(map(), FrontmanServer.Tools.Backend.Context.t()) ::
          FrontmanServer.Tools.Backend.result()
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

  # -- HTTP fetching ----------------------------------------------------------

  defp fetch_url(url) do
    case do_fetch(url, @chrome_ua) do
      {:cloudflare_challenge} ->
        case do_fetch(url, @honest_ua) do
          {:cloudflare_challenge} ->
            {:error, "Blocked by Cloudflare challenge"}

          other ->
            other
        end

      other ->
        other
    end
  end

  defp do_fetch(url, user_agent), do: do_fetch(url, user_agent, 0)

  defp do_fetch(_url, _user_agent, redirects)
       when redirects > @max_redirects do
    {:error, "Too many redirects"}
  end

  defp do_fetch(url, user_agent, redirects) do
    headers = [
      {"accept", "text/markdown, text/html;q=0.9, text/plain;q=0.8"},
      {"user-agent", user_agent}
    ]

    req_opts =
      [
        url: url,
        headers: headers,
        receive_timeout: 30_000,
        retry: false,
        decode_body: false,
        redirect: false
      ] ++ req_options()

    req_opts
    |> Req.get()
    |> handle_response(user_agent, redirects)
  end

  defp handle_response(
         {:ok, %Req.Response{status: status, headers: headers}},
         user_agent,
         redirects
       )
       when status in [301, 302, 303, 307, 308] do
    follow_redirect(headers, user_agent, redirects)
  end

  defp handle_response(
         {:ok, %Req.Response{status: 403, headers: headers}},
         _user_agent,
         _redirects
       ) do
    case cloudflare_challenge?(headers) do
      true -> {:cloudflare_challenge}
      false -> {:error, "HTTP 403"}
    end
  end

  defp handle_response(
         {:ok, %Req.Response{status: status, body: body, headers: headers}},
         _user_agent,
         _redirects
       )
       when status in 200..299 do
    case byte_size(body) > @max_response_bytes do
      true -> {:error, "Response too large (>5MB)"}
      false -> {:ok, get_content_type(headers), body}
    end
  end

  defp handle_response(
         {:ok, %Req.Response{status: status}},
         _user_agent,
         _redirects
       ) do
    {:error, "HTTP #{status}"}
  end

  defp handle_response(
         {:error, %Req.TransportError{reason: :timeout}},
         _user_agent,
         _redirects
       ) do
    {:error, "Request timed out"}
  end

  defp handle_response({:error, reason}, _user_agent, _redirects) do
    {:error, "Failed to fetch: #{inspect(reason)}"}
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

  # -- Content conversion -----------------------------------------------------

  defp convert_to_markdown(body, content_type) do
    case String.contains?(content_type, "text/html") do
      true -> Html2Markdown.convert(body)
      false -> body
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

  # -- URL validation ---------------------------------------------------------

  defp validate_url(%{"url" => url})
       when is_binary(url) and byte_size(url) > 0 do
    with :ok <- validate_scheme(url),
         {:ok, host} <- extract_host(url),
         :ok <- validate_host(host) do
      {:ok, url}
    end
  end

  defp validate_url(_), do: {:error, "url is required"}

  defp validate_scheme("http://" <> _), do: :ok
  defp validate_scheme("https://" <> _), do: :ok

  defp validate_scheme(_) do
    {:error, "URL must start with http:// or https://"}
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
    host
    |> String.downcase()
    |> do_validate_host()
  end

  defp do_validate_host("localhost"), do: ssrf_error()
  defp do_validate_host("localhost" <> _), do: ssrf_error()

  defp do_validate_host(host) do
    case String.ends_with?(host, [".local", ".internal", ".localhost"]) do
      true ->
        ssrf_error()

      false ->
        host
        |> String.to_charlist()
        |> check_ip_or_resolve()
    end
  end

  defp ssrf_error do
    {:error, "Requests to private/internal addresses are not allowed"}
  end

  # -- IP resolution and private range checks ---------------------------------

  defp check_ip_or_resolve(host_charlist) do
    case :inet.parse_address(host_charlist) do
      {:ok, ip} ->
        check_ip(ip)

      {:error, :einval} ->
        resolve_and_check(host_charlist)
    end
  end

  defp resolve_and_check(host_charlist) do
    case :inet.getaddrs(host_charlist, :inet) do
      {:ok, addrs} ->
        check_all_addrs(addrs)

      {:error, _} ->
        resolve_and_check_inet6(host_charlist)
    end
  end

  defp resolve_and_check_inet6(host_charlist) do
    case :inet.getaddrs(host_charlist, :inet6) do
      {:ok, addrs} -> check_all_addrs(addrs)
      {:error, _} -> :ok
    end
  end

  defp check_all_addrs(addrs) do
    case Enum.any?(addrs, &private_ip?/1) do
      true -> ssrf_error()
      false -> :ok
    end
  end

  defp check_ip(ip) do
    case private_ip?(ip) do
      true -> ssrf_error()
      false -> :ok
    end
  end

  # IPv4 private/reserved ranges.
  defp private_ip?({0, _, _, _}), do: true
  defp private_ip?({10, _, _, _}), do: true
  defp private_ip?({127, _, _, _}), do: true
  defp private_ip?({169, 254, _, _}), do: true
  defp private_ip?({172, b, _, _}) when b >= 16 and b <= 31, do: true
  defp private_ip?({192, 168, _, _}), do: true

  # IPv6 loopback and private.
  defp private_ip?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  defp private_ip?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp private_ip?({0xFC00, _, _, _, _, _, _, _}), do: true
  defp private_ip?({0xFD00, _, _, _, _, _, _, _}), do: true
  defp private_ip?({0xFE80, _, _, _, _, _, _, _}), do: true

  defp private_ip?(_), do: false

  # -- Utilities --------------------------------------------------------------

  defp clamp(val, min, :infinity) when is_integer(val) do
    max(val, min)
  end

  defp clamp(val, min, max_val) when is_integer(val) do
    val |> max(min) |> min(max_val)
  end

  defp clamp(_, min, _), do: min

  # Overridden in tests to inject Req.Test as the adapter.
  defp req_options do
    Application.get_env(:frontman_server, :web_fetch_req_options, [])
  end
end
