// Simple JSON decoders

// Generic schema parser - wraps S.parseOrThrow with Result error handling
let parseSchema = (json: JSON.t, schema: S.t<'a>): result<'a, string> => {
  try {
    Ok(json->S.parseOrThrow(~to=schema))
  } catch {
  | exn =>
    Error(exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Invalid JSON"))
  }
}
