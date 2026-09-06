defmodule FrontmanServer.Tools.BackendTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools.Backend

  setup_all do
    :ok
  end

  defmodule FakeBackendTool do
    @behaviour Backend

    def name, do: "fake_tool"
    def description, do: "A fake tool for testing"
    def access, do: :read
    def parameter_schema, do: %{}
    def timeout_ms, do: 45_000
    def execute(_args, _ctx), do: ModelContextProtocol.tool_result_text("done")
  end

  describe "to_swarm_tool/1" do
    test "builds SwarmAi.Tool with policy fields from callbacks" do
      tool = Backend.to_swarm_tool(FakeBackendTool)

      assert tool.name == "fake_tool"
      assert tool.description == "A fake tool for testing"
      assert tool.access == :read
      assert tool.parameter_schema == %{}
      refute Map.has_key?(tool, :timeout_ms)
      refute Map.has_key?(tool, :on_timeout)
    end
  end
end
