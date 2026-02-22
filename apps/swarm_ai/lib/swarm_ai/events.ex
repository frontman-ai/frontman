defmodule SwarmAi.Events do
  @moduledoc """
  Domain events emitted during SwarmAi execution.
  """
  use TypedStruct

  defmodule Started do
    @moduledoc "Emitted when an agent execution starts."
    use TypedStruct

    typedstruct do
      field(:execution_id, SwarmAi.Id.t())
      field(:message, String.t())
    end
  end

  defmodule Completed do
    @moduledoc "Emitted when an agent execution completes successfully."
    use TypedStruct

    typedstruct do
      field(:execution_id, SwarmAi.Id.t())
      field(:result, String.t())
    end
  end

  defmodule Failed do
    @moduledoc "Emitted when an agent execution fails."
    use TypedStruct

    typedstruct do
      field(:execution_id, SwarmAi.Id.t())
      field(:error, term())
    end
  end

  defmodule ToolCallRequested do
    @moduledoc "Emitted when a tool call is requested during execution."
    use TypedStruct

    typedstruct do
      field(:execution_id, SwarmAi.Id.t())
      field(:tool_call, SwarmAi.ToolCall.t())
    end
  end

  @type event :: Started.t() | Completed.t() | Failed.t() | ToolCallRequested.t()
end
