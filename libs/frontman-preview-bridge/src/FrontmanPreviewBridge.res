type config = {
  parentOrigin: string,
  channel: string,
}

type t = {
  runtime: Runtime.t<unit>,
  disposeInternal: unit => unit,
}

let pageHideEvent = WebAPI.EventTypes.Custom("pagehide")

let limits: Runtime.limits = {
  requestTimeoutMs: 5000,
  maxMessageBytes: 32_000_000,
  maxPendingRequests: 100,
}

let handler:
  type response. (Types.message<response>, unit, Runtime.context) => Response.t<response> =
  (message, _sender, _context) =>
    switch message {
    | FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview.GetDom(input) =>
      Response.now(FrontmanPreviewBridge__DomSnapshot.execute(input))
    | _ => Response.none
    }

let install: config => t = config => {
  let window = WebAPI.Window.current
  let transport = WindowTransport.Child.make({
    parentWindow: window->WebAPI.Window.parent,
    parentOrigin: config.parentOrigin,
    channel: config.channel,
    maxChunkBytes: 1_000_000,
  })
  let runtime = Runtime.make(transport, ~limits, ~handler)
  let disposed = ref(false)
  let removePageHide = ref(() => ())
  let disposeInternal = () => {
    switch disposed.contents {
    | true => ()
    | false => {
        disposed := true
        Runtime.close(runtime)
        removePageHide.contents()
      }
    }
  }
  let onPageHide = event => {
    switch FrontmanBindings.PageTransitionEvent.persisted(event) {
    | true => ()
    | false => disposeInternal()
    }
  }

  try {
    WebAPI.Window.addEventListener(window, pageHideEvent, onPageHide)
    removePageHide := (() => WebAPI.Window.removeEventListener(window, pageHideEvent, onPageHide))
  } catch {
  | error => {
      Runtime.close(runtime)
      throw(error)
    }
  }

  {
    runtime,
    disposeInternal,
  }
}

let dispose = installation => installation.disposeInternal()
