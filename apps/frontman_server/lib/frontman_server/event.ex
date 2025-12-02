defprotocol Event do
  @moduledoc """
  Protocol for domain events.
  
  Any event struct implements this protocol. Used by projection
  to identify and filter events.
  """
  
  @doc "Returns the event timestamp"
  def timestamp(event)
end
