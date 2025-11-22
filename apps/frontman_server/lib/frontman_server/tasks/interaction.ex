defmodule FrontmanServer.Tasks.Interaction do
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
    use TypedStruct

    typedstruct enforce: true do
      field :id, String.t()
      field :content, String.t()
      field :timestamp, DateTime.t()
      field :metadata, map(), enforce: false
    end
  end

  defimpl Jason.Encoder, for: UserMessage do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "user_message",
          id: value.id,
          content: value.content,
          timestamp: DateTime.to_iso8601(value.timestamp),
          metadata: value.metadata
        },
        opts
      )
    end
  end

  defmodule AgentResponse do
    @moduledoc """
    Represents a complete response from an agent.

    This is the final, stored interaction after streaming is complete.
    """
    use TypedStruct

    typedstruct enforce: true do
      field :id, String.t()
      field :agent_id, String.t()
      field :content, String.t()
      field :timestamp, DateTime.t()
      field :metadata, map(), enforce: false
    end
  end

  defimpl Jason.Encoder, for: AgentResponse do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "agent_response",
          id: value.id,
          agent_id: value.agent_id,
          content: value.content,
          timestamp: DateTime.to_iso8601(value.timestamp),
          metadata: value.metadata
        },
        opts
      )
    end
  end

  defmodule AgentSpawned do
    @moduledoc """
    Represents the creation of a new agent (including sub-agents).
    """
    use TypedStruct

    typedstruct enforce: true do
      field :id, String.t()
      field :agent_id, String.t()
      field :config, map(), enforce: false
      field :parent_agent_id, String.t() | nil, enforce: false
      field :timestamp, DateTime.t()
    end
  end

  defimpl Jason.Encoder, for: AgentSpawned do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "agent_spawned",
          id: value.id,
          agent_id: value.agent_id,
          config: value.config,
          parent_agent_id: value.parent_agent_id,
          timestamp: DateTime.to_iso8601(value.timestamp)
        },
        opts
      )
    end
  end

  defmodule AgentCompleted do
    @moduledoc """
    Represents an agent finishing its work.
    """
    use TypedStruct

    typedstruct enforce: true do
      field :id, String.t()
      field :agent_id, String.t()
      field :timestamp, DateTime.t()
      field :result, term(), enforce: false
    end
  end

  defimpl Jason.Encoder, for: AgentCompleted do
    def encode(value, opts) do
      Jason.Encode.map(
        %{
          type: "agent_completed",
          id: value.id,
          agent_id: value.agent_id,
          timestamp: DateTime.to_iso8601(value.timestamp),
          result: value.result
        },
        opts
      )
    end
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

  @doc """
  Converts interactions to LLM message format.

  This is the boundary translation from Tasks domain (Interactions)
  to Agents domain (LLM messages). Only conversation messages
  (UserMessage and AgentResponse) are included.
  """
  @spec to_llm_messages(list(t())) :: list(map())
  def to_llm_messages(interactions) do
    interactions
    |> Enum.filter(&is_conversation_message/1)
    |> Enum.map(&to_llm_message/1)
  end

  defp is_conversation_message(%UserMessage{}), do: true
  defp is_conversation_message(%AgentResponse{}), do: true
  defp is_conversation_message(_), do: false

  defp to_llm_message(%UserMessage{content: content}) do
    ReqLLM.Context.user(content)
  end

  defp to_llm_message(%AgentResponse{content: content}) do
    ReqLLM.Context.assistant(content)
  end
end
