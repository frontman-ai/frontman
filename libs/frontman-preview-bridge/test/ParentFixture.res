type browserWindow
type document
type iframe

type Types.message<_> += Never: Types.message<string>

@val external currentWindow: browserWindow = "window"
@val external document: document = "document"
@send external getElementById: (document, string) => Nullable.t<iframe> = "getElementById"
@get external contentWindow: iframe => browserWindow = "contentWindow"
@send external addEventListener: (iframe, string, unit => unit) => unit = "addEventListener"
@send external removeEventListener: (iframe, string, unit => unit) => unit = "removeEventListener"

let iframe =
  document
  ->getElementById("preview")
  ->Nullable.toOption
  ->Option.getOrThrow(~message="Parent fixture requires preview iframe")
let targetWindow = iframe->contentWindow
let limits: Runtime.limits = {
  requestTimeoutMs: 5000,
  maxMessageBytes: 32_000_000,
  maxPendingRequests: 100,
}
let handler:
  type response. (Types.message<response>, unit, Runtime.context) => Response.t<response> =
  (_message, _sender, _context) => Response.none
let transport = WindowTransport.Parent.make({
  targetWindow,
  targetOrigin: "http://127.0.0.1:4174",
  channel: "preview-task-id",
  subscribeLoad: listener => {
    iframe->addEventListener("load", listener)
    () => iframe->removeEventListener("load", listener)
  },
  connectionTimeoutMs: 1000,
  maxChunkBytes: 1_000_000,
})
let runtime = Runtime.make(transport, ~limits, ~handler)

let api: Dict.t<Obj.t> = Dict.make()
api->Dict.set(
  "isOpen",
  Obj.magic(() => {
    switch Runtime.status(runtime) {
    | Runtime.Open => true
    | Runtime.Connecting | Runtime.Disconnected(_) | Runtime.Closed(_) => false
    }
  }),
)
api->Dict.set(
  "isDisconnected",
  Obj.magic(() => {
    switch Runtime.status(runtime) {
    | Runtime.Disconnected(_) | Runtime.Closed(_) => true
    | Runtime.Connecting | Runtime.Open => false
    }
  }),
)
api->Dict.set("pending", Obj.magic(() => Runtime.sendMessage(runtime, Never)))
api->Dict.set("close", Obj.magic(() => Runtime.close(runtime)))
(Obj.magic(currentWindow): Dict.t<Obj.t>)->Dict.set("frontmanParentTest", Obj.magic(api))
