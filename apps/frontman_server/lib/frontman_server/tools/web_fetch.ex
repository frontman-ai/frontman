defmodule FrontmanServer.Tools.WebFetch do
  @moduledoc """
  Fetches web page content and returns it as markdown.

  Complements WebSearch (which finds URLs) by retrieving and processing
  content from known URLs. Supports line-based pagination for large pages.
  """

  @behaviour FrontmanServer.Tools.Backend

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
      _offset = clamp(Map.get(args, "offset", 0), 0, :infinity)
      _limit = clamp(Map.get(args, "limit", 500), 1, 2000)
      {:error, "not yet implemented: #{url}"}
    end
  end

  defp validate_url(%{"url" => url}) when is_binary(url) and byte_size(url) > 0 do
    if String.starts_with?(url, "http://") or String.starts_with?(url, "https://") do
      {:ok, url}
    else
      {:error, "URL must start with http:// or https://"}
    end
  end

  defp validate_url(_), do: {:error, "url is required"}

  defp clamp(val, min, :infinity) when is_integer(val), do: max(val, min)
  defp clamp(val, min, max_val) when is_integer(val), do: val |> max(min) |> min(max_val)
  defp clamp(_, min, _), do: min
end
