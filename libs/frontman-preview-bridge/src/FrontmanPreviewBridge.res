type config<'parentWindow> = {
  parentWindow: 'parentWindow,
  parentOrigin: string,
  channel: string,
}

type t = {
  parentWindow: Obj.t,
  parentOrigin: string,
  channel: string,
  runtime: Runtime.t<unit>,
  disposeInternal: unit => unit,
}

type slot = {
  marker: string,
  installation: t,
}

let currentWindow = () => WebAPI.Window.current
let pageHideEvent = WebAPI.EventTypes.Custom("pagehide")
let installationKey = FrontmanBindings.Symbol.for_(
  "@frontman-ai/frontman-preview-bridge/installation",
)
let installationMarker = "@frontman-ai/frontman-preview-bridge/installation/v1"

let limits: Runtime.limits = {
  requestTimeoutMs: 5000,
  maxMessageBytes: 32_000_000,
  maxPendingRequests: 100,
}

let handler:
  type response. (Types.message<response>, unit, Runtime.context) => Response.t<response> =
  (_message, _sender, _context) => Response.none

let existing = (): option<t> => {
  switch FrontmanBindings.BrowserWindow.getBySymbol(
    currentWindow(),
    installationKey,
  )->Nullable.toOption {
  | None => None
  | Some(value) => {
      let slot: slot = Obj.magic(value)
      switch slot.marker === installationMarker {
      | true => Some(slot.installation)
      | false =>
        JsError.throwWithMessage("Frontman preview bridge installation slot is already occupied")
      }
    }
  }
}

let sameConfig:
  type parentWindow. (t, config<parentWindow>) => bool =
  (installation, config) =>
    installation.parentWindow === Obj.magic(config.parentWindow) &&
    installation.parentOrigin === config.parentOrigin &&
    installation.channel === config.channel

let create:
  type parentWindow. config<parentWindow> => t =
  config => {
    let window = currentWindow()
    let parentWindow = Obj.magic(config.parentWindow)
    let transport = WindowTransport.Child.make({
      parentWindow: config.parentWindow,
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
        JsError.throw(Obj.magic(error))
      }
    }

    {
      parentWindow,
      parentOrigin: config.parentOrigin,
      channel: config.channel,
      runtime,
      disposeInternal,
    }
  }

let install:
  type parentWindow. config<parentWindow> => t =
  config => {
    switch existing() {
    | Some(installation) if sameConfig(installation, config) => installation
    | Some(_) =>
      JsError.throwWithMessage(
        "Frontman preview bridge is already installed with different configuration",
      )
    | None => {
        let installation = create(config)
        try {
          FrontmanBindings.BrowserWindow.setBySymbol(
            currentWindow(),
            installationKey,
            Obj.magic({
              marker: installationMarker,
              installation,
            }),
          )
          installation
        } catch {
        | error => {
            installation.disposeInternal()
            JsError.throw(Obj.magic(error))
          }
        }
      }
    }
  }

let status = installation => Runtime.status(installation.runtime)
let dispose = installation => installation.disposeInternal()
