defmodule FrontmanServer.Testing.BlockingLLM do
  @moduledoc false
  # LLM stub that blocks indefinitely in stream/3. Used in channel tests where
  # session/prompt is pushed to exercise channel behavior, but the actual LLM
  # response is never needed — the test injects swarm events manually.
  #
  # The agent process spawned by Runtime runs but never completes, so
  # SwarmDispatcher never runs DB writes, producing no log noise and no Ecto
  # sandbox ownership errors.
  defstruct model: "blocking"
end

defimpl SwarmAi.LLM, for: FrontmanServer.Testing.BlockingLLM do
  def stream(_llm, _messages, _opts) do
    # Block until the process is killed (never completes normally).
    receive do
      :never -> :ok
    end

    {:error, :blocked}
  end
end

defmodule FrontmanServer.Testing.BlockingAgent do
  @moduledoc false
  defstruct []
end

defimpl SwarmAi.Agent, for: FrontmanServer.Testing.BlockingAgent do
  def system_prompt(_), do: "blocking test agent"
  def llm(_), do: %FrontmanServer.Testing.BlockingLLM{}
  def init(_), do: {:ok, %{}, []}
  def should_terminate?(_, _, _), do: false
end
