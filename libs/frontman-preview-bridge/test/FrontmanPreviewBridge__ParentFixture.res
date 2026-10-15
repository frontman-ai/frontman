module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview

let handler:
  type response. (Types.message<response>, unit, Runtime.context) => Response.t<response> =
  (_message, _sender, _context) => Response.none

let requestPageContext = async () => {
  let iframe =
    WebAPI.Window.current
    ->WebAPI.Window.document
    ->WebAPI.Document.querySelector("iframe")
    ->Null.toOption
    ->Option.flatMap(FrontmanBindings.Bindings__WebAPI.iframeElementFromElement)
    ->Option.getOrThrow(~message="Browser fixture requires an iframe")
  let transport = WindowTransport.Parent.make({
    targetWindow: iframe->WebAPI.HTMLIFrameElement.contentWindow->Option.getOrThrow,
    targetOrigin: "https://site.test",
    channel: "task",
    subscribeLoad: listener => {
      let onLoad = _event => listener()
      iframe->WebAPI.HTMLIFrameElement.addEventListener(WebAPI.EventTypes.Load, onLoad)
      () => iframe->WebAPI.HTMLIFrameElement.removeEventListener(WebAPI.EventTypes.Load, onLoad)
    },
    connectionTimeoutMs: 2000,
    maxChunkBytes: 1_000_000,
  })
  let runtime = Runtime.make(
    transport,
    ~limits={requestTimeoutMs: 2000, maxMessageBytes: 32_000_000, maxPendingRequests: 100},
    ~handler,
  )
  try {
    await Runtime.whenOpen(runtime)
    let context = await Runtime.sendMessage(runtime, Preview.GetPageContext)
    Runtime.close(runtime)
    context
  } catch {
  | exn => {
      Runtime.close(runtime)
      throw(exn)
    }
  }
}
