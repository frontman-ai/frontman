defmodule FrontmanNotifier.GitHub do
  @moduledoc """
  GitHub API client for repository stargazers and user profiles.
  """

  alias FrontmanNotifier.Config

  @timeout_ms 15_000
  @stargazer_accept "application/vnd.github.star+json"
  @json_accept "application/vnd.github+json"

  @spec fetch_stargazers() :: {:ok, list(map())} | {:error, term()}
  def fetch_stargazers do
    with {:ok, first_page, last_page} <- fetch_stargazer_page(1) do
      last_page
      |> stargazer_pages()
      |> fetch_remaining_stargazer_pages(first_page)
      |> dedupe_stargazers()
    end
  end

  @spec fetch_user(String.t()) :: {:ok, map()} | {:error, term()}
  def fetch_user(login) when is_binary(login) do
    Config.github_api_base_url()
    |> join_path(["users", URI.encode(login)])
    |> get_json(@json_accept, [])
  end

  defp fetch_stargazer_page(page) when is_integer(page) and page > 0 do
    Config.github_api_base_url()
    |> join_path(["repos", Config.github_repository(), "stargazers"])
    |> get_json_response(@stargazer_accept, page: page, per_page: 100)
    |> case do
      {:ok, body, headers} when is_list(body) ->
        {:ok, Enum.map(body, &normalize_stargazer/1), last_page(headers)}

      {:ok, body, _headers} ->
        {:error, {:unexpected_stargazers_body, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_json(url, accept, params) do
    case get_json_response(url, accept, params) do
      {:ok, body, _headers} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_json_response(url, accept, params) do
    case Req.get(url,
           headers: headers(accept),
           params: params,
           receive_timeout: @timeout_ms,
           retry: false
         ) do
      {:ok, %{status: status, body: body, headers: headers}} when status in 200..299 ->
        {:ok, body, headers}

      {:ok, %{status: status, body: body}} ->
        {:error, {:github_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stargazer_pages(nil) do
    Enum.to_list(1..Config.github_stargazer_pages())
  end

  defp stargazer_pages(last_page) when is_integer(last_page) and last_page > 0 do
    page_budget = Config.github_stargazer_pages()

    cond do
      last_page <= page_budget ->
        Enum.to_list(1..last_page)

      page_budget == 1 ->
        [1, last_page]

      true ->
        tail_start = last_page - page_budget + 2
        [1 | Enum.to_list(tail_start..last_page)]
    end
  end

  defp fetch_remaining_stargazer_pages(pages, first_page) do
    pages
    |> Enum.reject(&(&1 == 1))
    |> Enum.reduce_while({:ok, first_page}, &fetch_stargazer_page_into_acc/2)
  end

  defp fetch_stargazer_page_into_acc(page, {:ok, acc}) do
    case fetch_stargazer_page(page) do
      {:ok, [], _last_page} -> {:halt, {:ok, acc}}
      {:ok, page_stargazers, _last_page} -> {:cont, {:ok, acc ++ page_stargazers}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp dedupe_stargazers({:ok, stargazers}) do
    {:ok, Enum.uniq_by(stargazers, & &1["login"])}
  end

  defp dedupe_stargazers({:error, reason}), do: {:error, reason}

  defp last_page(headers) do
    headers
    |> response_header("link")
    |> parse_last_page()
  end

  defp response_header(headers, wanted_name) when is_list(headers) do
    Enum.find_value(headers, fn {name, value} ->
      case String.downcase(to_string(name)) == wanted_name do
        true -> header_value(value)
        false -> nil
      end
    end)
  end

  defp response_header(headers, wanted_name) when is_map(headers) do
    Enum.find_value(headers, fn {name, value} ->
      case String.downcase(to_string(name)) == wanted_name do
        true -> header_value(value)
        false -> nil
      end
    end)
  end

  defp header_value([value | _]), do: value
  defp header_value(value), do: value

  defp parse_last_page(nil), do: nil

  defp parse_last_page(link_header) when is_binary(link_header) do
    case Regex.run(~r/[?&]page=(\d+)[^>]*>; rel="last"/, link_header) do
      [_match, page] -> String.to_integer(page)
      nil -> nil
    end
  end

  defp parse_last_page(_link_header), do: nil

  defp headers(accept) do
    base = [
      {"accept", accept},
      {"user-agent", "frontman-notifier"},
      {"x-github-api-version", "2022-11-28"}
    ]

    case Config.github_token() do
      nil -> base
      token -> [{"authorization", "Bearer #{token}"} | base]
    end
  end

  defp normalize_stargazer(%{"user" => user, "starred_at" => starred_at}) when is_map(user) do
    Map.put(user, "starred_at", starred_at)
  end

  defp normalize_stargazer(user) when is_map(user), do: Map.put_new(user, "starred_at", nil)

  defp join_path(base_url, segments) do
    encoded_path = Enum.join(segments, "/")
    String.trim_trailing(base_url, "/") <> "/" <> encoded_path
  end
end
