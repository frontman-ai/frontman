type t = [
  | #Global
  | #ACP
  | #MCP
  | #MCPServer
  | #Relay
  | #SSE
  | #Session
  | #Phoenix
  | #ConnectionReducer
  | #StateReducer
  | #TaskReducer
  | #Chatbox
  | #FrontmanProvider
  | #WebPreviewStage
  | #StateStore
  | #BrowserUrl
]

external componentToString: [> t] => string = "%identity"
