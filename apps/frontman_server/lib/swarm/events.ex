defmodule Swarm.Events do
  @moduledoc """
  Domain events emitted during Swarm execution.
  """
  use TypedStruct

  defmodule Started do
    @moduledoc false
    use TypedStruct

    typedstruct do
      field :execution_id, Swarm.Id.t()
      field :message, String.t()
    end
  end

  defmodule Completed do
    @moduledoc false
    use TypedStruct

    typedstruct do
      field :execution_id, Swarm.Id.t()
      field :result, String.t()
    end
  end

  defmodule Failed do
    @moduledoc false
    use TypedStruct

    typedstruct do
      field :execution_id, Swarm.Id.t()
      field :error, term()
    end
  end

  defmodule ToolCallRequested do
    @moduledoc false
    use TypedStruct

    typedstruct do
      field :execution_id, Swarm.Id.t()
      field :tool_call, Swarm.ToolCall.t()
    end
  end

  @type event :: Started.t() | Completed.t() | Failed.t() | ToolCallRequested.t()
end
