// Low-level bindings to Phoenix Channel class

type t = FrontmanClient__Phoenix__Socket.channel

type channelEvent = [
  | #interaction
  | #stream_token
  | #agent_completed
  | #agent_error
  | #send_message
  // ACP events
  | #"acp:message"
  // MCP events (all MCP JSON-RPC goes through mcp:message)
  | #"mcp:message"
  // Session management (non-ACP)
  | #list_sessions
  | #delete_session
  | #title_updated
  | #config_options_updated
]

type rec pushResponse = {receive: (~status: string, ~callback: JSON.t => unit) => pushResponse}

@send external join: (t, ~timeout: int=?) => pushResponse = "join"

@send external leave: (t, ~timeout: int=?) => pushResponse = "leave"

@send
external push: (t, ~event: channelEvent, ~payload: JSON.t, ~timeout: int=?) => pushResponse = "push"

@send external on: (t, ~event: channelEvent, ~callback: JSON.t => unit) => unit = "on"

@send external off: (t, ~event: channelEvent) => unit = "off"

@get external state: t => string = "state"
