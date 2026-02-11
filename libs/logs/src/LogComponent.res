type t = [
  | #Global
  | #ACP
  | #MCP
  | #MCPServer
  | #Relay
  | #Session
  | #Phoenix
]

// Accepts any poly variant (open) — tags are strings at runtime
external componentToString: [> t] => string = "%identity"
