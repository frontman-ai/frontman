external window: DomTypes.window = "window"
external document: DomTypes.document = "document"
external location: DomTypes.location = "location"
external history: HistoryTypes.history = "history"
external crypto: WebCryptoTypes.crypto = "crypto"
type navigator = {clipboard: ClipboardTypes.clipboard}
external navigator: navigator = "navigator"
external devicePixelRatio: float = "devicePixelRatio"

external fetch: (string, ~init: Request.requestInit=?) => promise<Response.t> = "fetch"

@val
external requestAnimationFrame: (float => unit) => int = "requestAnimationFrame"

@val
external cancelAnimationFrame: int => unit = "cancelAnimationFrame"

@val
external setTimeout: (~handler: unit => unit, ~timeout: int) => int = "setTimeout"

@val
external clearTimeout: int => unit = "clearTimeout"

@val
external setInterval: (~handler: unit => unit, ~timeout: int) => int = "setInterval"

@val
external setInterval2: (~handler: unit => unit, ~timeout: int=?) => int = "setInterval"

@val
external clearInterval: int => unit = "clearInterval"

@val
external top: DomTypes.window = "top"
