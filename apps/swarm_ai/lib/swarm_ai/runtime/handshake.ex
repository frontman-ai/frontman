defmodule SwarmAi.Runtime.Handshake do
  @moduledoc false
  use TypedStruct

  typedstruct enforce: true do
    field(:caller, pid())
    field(:ack_ref, reference())
  end
end
