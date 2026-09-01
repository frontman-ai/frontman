defmodule ModelContextProtocol.ToolCallParams do
  @enforce_keys [:request_id, :task_id, :tool_name, :arguments, :tool_call_id]
  @type t :: %__MODULE__{
          request_id: String.t() | integer(),
          task_id: String.t(),
          tool_name: String.t(),
          arguments: map(),
          tool_call_id: String.t()
        }
  defstruct request_id: nil,
            task_id: nil,
            tool_name: nil,
            arguments: nil,
            tool_call_id: nil
end
