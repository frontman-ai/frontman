defmodule FrontmanServer.Interaction do
  @moduledoc """
  Domain interaction types for the LLM agent system.

  Interactions represent domain events that occur during a task's lifecycle.
  These are stored as the source of truth, while streaming tokens are ephemeral
  transport mechanisms for real-time UX.
  """

  @type t ::
          UserMessage.t()
          | AgentResponse.t()
          | AgentSpawned.t()
          | AgentCompleted.t()

  defmodule UserMessage do
    @moduledoc """
    Represents a message sent by the user.
    """
    @enforce_keys [:id, :content, :timestamp]
    defstruct [:id, :content, :timestamp, metadata: %{}]

    @type t :: %__MODULE__{
            id: String.t(),
            content: String.t(),
            timestamp: DateTime.t(),
            metadata: map()
          }
  end

  defmodule AgentResponse do
    @moduledoc """
    Represents a complete response from an agent.

    This is the final, stored interaction after streaming is complete.
    """
    @enforce_keys [:id, :agent_id, :content, :timestamp]
    defstruct [:id, :agent_id, :content, :timestamp, metadata: %{}]

    @type t :: %__MODULE__{
            id: String.t(),
            agent_id: String.t(),
            content: String.t(),
            timestamp: DateTime.t(),
            metadata: map()
          }
  end

  defmodule AgentSpawned do
    @moduledoc """
    Represents the creation of a new agent (including sub-agents).
    """
    @enforce_keys [:id, :agent_id, :agent_type, :timestamp]
    defstruct [:id, :agent_id, :agent_type, :config, :parent_agent_id, :timestamp]

    @type t :: %__MODULE__{
            id: String.t(),
            agent_id: String.t(),
            agent_type: String.t(),
            config: map(),
            parent_agent_id: String.t() | nil,
            timestamp: DateTime.t()
          }
  end

  defmodule AgentCompleted do
    @moduledoc """
    Represents an agent finishing its work.
    """
    @enforce_keys [:id, :agent_id, :timestamp]
    defstruct [:id, :agent_id, :timestamp, :result]

    @type t :: %__MODULE__{
            id: String.t(),
            agent_id: String.t(),
            timestamp: DateTime.t(),
            result: term()
          }
  end

  @doc """
  Generates a new interaction ID (UUID v4).
  """
  def new_id do
    Ecto.UUID.generate()
  end

  @doc """
  Returns the current timestamp.
  """
  def now do
    DateTime.utc_now()
  end
end
