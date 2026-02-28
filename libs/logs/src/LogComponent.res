type t = [
  | #Global
  | #ACP
  | #MCP
  | #MCPServer
  | #Relay
  | #Session
  | #Phoenix
  | #ConnectionReducer
  | #StateReducer
  | #TaskReducer
  | #Chatbox
  | #FrontmanProvider
  | #WebPreviewStage
  | #StateStore
]

// Accepts any poly variant (open) — tags are strings at runtime
external componentToString: [> t] => string = "%identity"
