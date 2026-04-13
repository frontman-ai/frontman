defmodule FrontmanServer.Sandbox.RepoAnalyzer do
  @moduledoc """
  Entry point for environment detection.

  Given a GitHub repo and token, fetches the repo's devcontainer.json
  and returns it as an EnvironmentSpec. If no devcontainer.json is
  found, returns a structured error rather than generating one — MVP
  scope only.
  """

  alias FrontmanServer.Sandbox.{EnvironmentSpec, GitHubClient}

  @devcontainer_paths [
    ".devcontainer/devcontainer.json",
    ".devcontainer.json",
    "devcontainer.json"
  ]

  @spec analyze(String.t(), String.t(), keyword()) ::
          {:ok, EnvironmentSpec.t()}
          | {:error,
             :no_devcontainer
             | :invalid_json
             | :invalid_repo_format
             | :unauthorized
             | :not_found
             | {:github_error, integer(), term()}
             | term()}
  def analyze(github_repo, token, opts \\ [])
      when is_binary(github_repo) and is_binary(token) do
    client = Keyword.get(opts, :github_client, github_client())

    case String.split(github_repo, "/", parts: 2) do
      [owner, repo] -> do_analyze(client, owner, repo, token)
      _ -> {:error, :invalid_repo_format}
    end
  end

  defp do_analyze(client, owner, repo, token) do
    with {:ok, tree} <- client.get_tree(owner, repo, "HEAD", token),
         {:ok, path} <- find_devcontainer(tree),
         {:ok, content} <- client.get_file(owner, repo, path, token),
         {:ok, map} <- decode_json(content) do
      EnvironmentSpec.new(map)
    else
      {:error, {:http_error, 401, _}} -> {:error, :unauthorized}
      {:error, {:http_error, 404, _}} -> {:error, :not_found}
      {:error, {:http_error, status, body}} -> {:error, {:github_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp github_client do
    Application.get_env(:frontman_server, :github_client, GitHubClient.Req)
  end

  defp find_devcontainer(tree) do
    paths = MapSet.new(tree, & &1["path"])

    case Enum.find(@devcontainer_paths, &MapSet.member?(paths, &1)) do
      nil -> {:error, :no_devcontainer}
      path -> {:ok, path}
    end
  end

  defp decode_json(content) do
    case Jason.decode(content) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _} -> {:error, :invalid_json}
      {:error, _} -> {:error, :invalid_json}
    end
  end
end
