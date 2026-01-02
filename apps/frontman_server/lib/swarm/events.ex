defmodule Swarm.Events do
  use TypedStruct

  defmodule Started do
    use TypedStruct

    typedstruct do
      field :execution_id, Swarm.Id.t()
      field :message, String.t()
    end
  end

  defmodule Completed do
    use TypedStruct

    typedstruct do
      field :execution_id, Swarm.Id.t()
      field :result, String.t()
    end
  end

  defmodule Failed do
    use TypedStruct

    typedstruct do
      field :execution_id, Swarm.Id.t()
      field :error, term()
    end
  end

  defmodule ToolCallRequested do
    use TypedStruct

    typedstruct do
      field :execution_id, Swarm.Id.t()
      field :tool_call, Swarm.ToolCall.t()
    end
  end

  @type event :: Started.t() | Completed.t() | Failed.t() | ToolCallRequested.t()
end
