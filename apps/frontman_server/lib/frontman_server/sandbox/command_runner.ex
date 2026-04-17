defmodule FrontmanServer.Sandbox.CommandRunner do
  @moduledoc """
  Behaviour for executing system commands.

  Abstracts `System.cmd/3` so the Microsandbox provider can be tested
  without shelling out to real processes. Same pattern as `GitHubClient`
  for GitHub API calls.
  """

  @type result :: {output :: String.t(), exit_code :: non_neg_integer()}

  @callback run(command :: String.t(), args :: [String.t()], opts :: keyword()) :: result()
end
