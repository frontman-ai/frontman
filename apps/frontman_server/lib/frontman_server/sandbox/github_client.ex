defmodule FrontmanServer.Sandbox.GitHubClient do
  @moduledoc """
  Behaviour for the GitHub API client used by RepoAnalyzer.

  Abstracted so the HTTP layer is swappable in tests via Mox.
  """

  @callback get_tree(
              owner :: String.t(),
              repo :: String.t(),
              ref :: String.t(),
              token :: String.t()
            ) ::
              {:ok, [map()]} | {:error, {:http_error, integer(), term()} | term()}

  @callback get_file(
              owner :: String.t(),
              repo :: String.t(),
              path :: String.t(),
              token :: String.t()
            ) ::
              {:ok, String.t()} | {:error, {:http_error, integer(), term()} | term()}
end
