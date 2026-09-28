type t = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.previewContext

let exnMessage = (exn: exn): string =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")

let get = (): option<t> => {
  let state = StateStore.getState(Client__State__Store.store)
  let previewFrame = Client__State__StateReducer.Selectors.previewFrame(state)
  switch (previewFrame.contentDocument, previewFrame.contentWindow) {
  | (Some(doc), Some(win)) => Some({doc, win})
  | (Some(_), None) | (None, Some(_)) | (None, None) => None
  }
}

let withPreview = (~onUnavailable: unit => 'a, fn: t => 'a): 'a =>
  switch get() {
  | Some(context) => fn(context)
  | None => onUnavailable()
  }
