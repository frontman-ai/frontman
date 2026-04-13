defmodule FrontmanServer.Sandbox.GitHubClient.Req do
  @moduledoc """
  Production GitHub API client using Req.

  Uses `Authorization: Bearer {token}` for all requests.
  Returns decoded tree entries and raw file content strings.
  """

  @behaviour FrontmanServer.Sandbox.GitHubClient

  @base_url "https://api.github.com"
  @timeout_ms 15_000

  @impl true
  def get_tree(owner, repo, ref, token) do
    url = "#{@base_url}/repos/#{owner}/#{repo}/git/trees/#{ref}?recursive=1"

    case Req.get(url, headers: auth_headers(token), receive_timeout: @timeout_ms) do
      {:ok, %{status: 200, body: %{"tree" => tree}}} ->
        {:ok, tree}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def get_file(owner, repo, path, token) do
    url = "#{@base_url}/repos/#{owner}/#{repo}/contents/#{path}"

    case Req.get(url, headers: auth_headers(token), receive_timeout: @timeout_ms) do
      {:ok, %{status: 200, body: %{"content" => content, "encoding" => "base64"}}} ->
        case content |> String.replace("\n", "") |> Base.decode64() do
          {:ok, decoded} -> {:ok, decoded}
          :error -> {:error, {:decode_error, :invalid_base64}}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp auth_headers(token), do: [{"authorization", "Bearer #{token}"}]
end
