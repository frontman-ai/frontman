defmodule FrontmanServer.MCPTerminalRequestsTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.MCPTerminalRequests

  test "retains exactly 4,096 records and the 4,097th evicts the oldest" do
    records = Enum.reduce(1..4_096, [], &remember(&2, &1, 0))

    assert length(records) == 4_096
    assert {:late, %{id: 1}, ^records} = MCPTerminalRequests.classify(records, 1, 0)

    records = remember(records, 4_097, 0)

    assert length(records) == 4_096
    assert {:unknown, nil, ^records} = MCPTerminalRequests.classify(records, 1, 0)
    assert {:late, %{id: 4_097}, ^records} = MCPTerminalRequests.classify(records, 4_097, 0)
  end

  test "retains through 15 minutes and expires one millisecond later" do
    records = remember([], "typed-id", 0)

    assert {:late, record, ^records} = MCPTerminalRequests.classify(records, "typed-id", 900_000)
    assert record.terminal_time_ms == 0
    assert {:unknown, nil, []} = MCPTerminalRequests.classify(records, "typed-id", 900_001)
  end

  test "preserves exact JSON ID type and classifies response terminals as duplicates" do
    records = remember([], 1, 0, :response)

    assert {:duplicate, %{id: 1}, ^records} = MCPTerminalRequests.classify(records, 1, 0)
    assert {:unknown, nil, ^records} = MCPTerminalRequests.classify(records, "1", 0)
  end

  defp remember(records, id, now_ms, reason \\ :cancelled) do
    MCPTerminalRequests.remember(
      records,
      %{id: id, method: "tools/call", kind: :tool, reason: reason, former_owner: self()},
      now_ms
    )
  end
end
