let _fromURL = WebSocket.fromURL(~url="wss://example.com/socket")

let _fromURLWithProtocols = WebSocket.fromURLWithProtocols(
  ~url="wss://example.com/socket",
  ~protocols=["chat", "superchat"],
)
