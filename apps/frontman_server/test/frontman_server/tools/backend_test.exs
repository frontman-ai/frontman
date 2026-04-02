defmodule FrontmanServer.Tools.BackendTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools.Backend

  setup_all do
    # Prevent test_helper.exs from trying to setup Ecto.Adapters.SQL.Sandbox
    :ok
  end

  defmodule FakeBackendTool do
    @behaviour Backend

    def name, do: "fake_tool"
    def description, do: "A fake tool for testing"
    def parameter_schema, do: %{}
    def timeout_ms, do: 45_000
    def on_timeout, do: :error
    def execute(_args, _ctx), do: {:ok, "done"}
  end

  describe "to_swarm_tool/1" do
    test "builds SwarmAi.Tool with policy fields from callbacks" do
      tool = Backend.to_swarm_tool(FakeBackendTool)

      assert tool.name == "fake_tool"
      assert tool.description == "A fake tool for testing"
      assert tool.parameter_schema == %{}
      assert tool.timeout_ms == 45_000
      assert tool.on_timeout == :error
    end
  end
end
