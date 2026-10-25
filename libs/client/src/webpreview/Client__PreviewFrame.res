module Browser = FrontmanBindings.Bindings__WebAPI
type context = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.previewContext

/// Re-read the live document: a WindowProxy keeps its identity across navigations.
/// A cached document must never service a call for the replacement page.
let validate = (~doc, ~window: Browser.windowHandle): option<context> =>
  try {
    switch WebAPI.Window.document(window.window) === doc {
    | true => Some({doc, win: window.window})
    | false => None
    }
  } catch {
  | exn if Browser.isSecurityError(exn) => None
  | exn => throw(exn)
  }

let read = (iframe: WebAPI.DomTypes.htmliFrameElement): option<context> =>
  try {
    switch (WebAPI.HTMLIFrameElement.contentDocument(iframe), Browser.iframeWindowHandle(iframe)) {
    | (Some(doc), Some(window)) => validate(~doc, ~window)
    | (None, _) | (_, None) => None
    }
  } catch {
  | exn if Browser.isSecurityError(exn) => None
  | exn => throw(exn)
  }
