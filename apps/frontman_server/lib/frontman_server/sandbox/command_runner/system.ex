defmodule FrontmanServer.Sandbox.CommandRunner.System do
  @moduledoc false

  @behaviour FrontmanServer.Sandbox.CommandRunner

  @impl true
  def run(command, args, opts) do
    System.cmd(command, args, opts)
  end
end
