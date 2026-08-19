type t = Runtime.t<unit>

let limits: Runtime.limits = {
  requestTimeoutMs: 5000,
  maxMessageBytes: 32_000_000,
  maxPendingRequests: 100,
}

let handler:
  type response. (Types.message<response>, unit, Runtime.context) => Response.t<response> =
  (_message, _sender, _context) => Response.none

let make = (~iframe: WebAPI.DomTypes.element, ~targetOrigin, ~channel) => {
  let iframeElement: WebAPI.DomTypes.htmliFrameElement = Obj.magic(iframe)
  let targetWindow =
    iframeElement
    ->WebAPI.HTMLIFrameElement.contentWindow
    ->Option.getOrThrow(~message="Preview iframe requires a contentWindow")
  let iframeTarget: WebAPI.DomTypes.eventTarget = Obj.magic(iframe)
  let transport = WindowTransport.Parent.make({
    targetWindow,
    targetOrigin,
    channel,
    subscribeLoad: listener => {
      let onLoad = _event => listener()
      iframeTarget->WebAPI.EventTarget.addEventListener(WebAPI.EventTypes.Load, onLoad)
      () => iframeTarget->WebAPI.EventTarget.removeEventListener(WebAPI.EventTypes.Load, onLoad)
    },
    connectionTimeoutMs: 5000,
    maxChunkBytes: 1_000_000,
  })

  Runtime.make(transport, ~limits, ~handler)
}

let status = Runtime.status
let onStatus = Runtime.onStatus
let whenOpen = Runtime.whenOpen
let close = Runtime.close
