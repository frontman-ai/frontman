module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc

type envelopeFields = {
  jsonrpc: string,
  id: JsonRpc.Id.t,
  method: string,
  params: option<JSON.t>,
}

type idFields = {id: JsonRpc.Id.t}

type t = {
  raw: JSON.t,
  id: JsonRpc.Id.t,
  method: string,
  params: option<JSON.t>,
}

type classificationError = InvalidEnvelopeOrDirection

let fieldsSchema = S.object(s => {
  let fields: envelopeFields = {
    jsonrpc: s.field("jsonrpc", S.literal(JsonRpc.version)),
    id: s.field("id", JsonRpc.Id.schema),
    method: s.field("method", S.string),
    params: s.field("params", S.option(S.json)),
  }
  fields
})

let requestSchema = JsonRpc.Wire.withoutFields(fieldsSchema, ["result", "error"])

let idSchema = S.object(s => {
  let fields: idFields = {id: s.field("id", JsonRpc.Id.schema)}
  fields
})

let classify = (json: JSON.t): result<t, classificationError> => {
  try {
    let raw = json->S.parseOrThrow(~to=requestSchema)
    let fields = raw->S.parseOrThrow(~to=fieldsSchema)
    Ok({raw, id: fields.id, method: fields.method, params: fields.params})
  } catch {
  | S.Exn(_) => Error(InvalidEnvelopeOrDirection)
  | exn => throw(exn)
  }
}

let recoverId = (json: JSON.t): option<JsonRpc.Id.t> => {
  try {
    let fields = json->S.parseOrThrow(~to=idSchema)
    Some(fields.id)
  } catch {
  | S.Exn(_) => None
  | exn => throw(exn)
  }
}
