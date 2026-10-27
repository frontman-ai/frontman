module Browser = FrontmanBindings.Bindings__WebAPI
type context = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.previewContext

/// Re-read the live document: a WindowProxy keeps its identity across navigations.
/// A cached document must never service a call for the replacement page.
let isCurrent = (~doc, ~window: Browser.windowHandle): bool =>
  try {
    WebAPI.Window.document(window.window) === doc
  } catch {
  | exn if Browser.isSecurityError(exn) => false
  | exn => throw(exn)
  }

let read = (iframe: WebAPI.DomTypes.htmliFrameElement): option<context> =>
  try {
    switch (WebAPI.HTMLIFrameElement.contentDocument(iframe), Browser.iframeWindowHandle(iframe)) {
    | (Some(doc), Some(window)) if isCurrent(~doc, ~window) => Some({doc, win: window.window})
    | (Some(_), Some(_)) | (None, _) | (_, None) => None
    }
  } catch {
  | exn if Browser.isSecurityError(exn) => None
  | exn => throw(exn)
  }
