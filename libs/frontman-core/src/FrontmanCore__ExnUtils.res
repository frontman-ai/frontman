let message = (exn: exn): string =>
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
