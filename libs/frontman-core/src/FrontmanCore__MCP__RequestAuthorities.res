module RequestEnvelope = FrontmanCore__MCP__RequestEnvelope

type metadataFields = {
  protocolVersion: option<JSON.t>,
  clientCapabilities: option<JSON.t>,
}

type paramsFields = {
  metadata: option<JSON.t>,
  name: option<JSON.t>,
  uri: option<JSON.t>,
}

type headerFields = {
  protocolVersion: option<JSON.t>,
  method: string,
  name: option<JSON.t>,
}

type t = {
  headers: headerFields,
  metadata: option<JSON.t>,
  clientCapabilities: option<JSON.t>,
}

let metadataSchema = S.object(s => {
  let fields: metadataFields = {
    protocolVersion: s.field("io.modelcontextprotocol/protocolVersion", S.option(S.json)),
    clientCapabilities: s.field("io.modelcontextprotocol/clientCapabilities", S.option(S.json)),
  }
  fields
})

let paramsSchema = S.object(s => {
  let fields: paramsFields = {
    metadata: s.field("_meta", S.option(S.json)),
    name: s.field("name", S.option(S.json)),
    uri: s.field("uri", S.option(S.json)),
  }
  fields
})

let parseParams = params => {
  try {
    Some(params->S.parseOrThrow(~to=paramsSchema))
  } catch {
  | S.Exn(_) => None
  | exn => throw(exn)
  }
}

let parseMetadata = metadata => {
  try {
    Some(metadata->S.parseOrThrow(~to=metadataSchema))
  } catch {
  | S.Exn(_) => None
  | exn => throw(exn)
  }
}

let nameForMethod = (~method, ~params: option<paramsFields>) => {
  switch (method, params) {
  | ("tools/call" | "prompts/get", Some(params)) => params.name
  | ("resources/read", Some(params)) => params.uri
  | _ => None
  }
}

let extract = (envelope: RequestEnvelope.t): t => {
  let params = envelope.params->Option.flatMap(parseParams)
  let metadata = params->Option.flatMap(params => params.metadata)->Option.flatMap(parseMetadata)

  {
    headers: {
      protocolVersion: metadata->Option.flatMap(metadata => metadata.protocolVersion),
      method: envelope.method,
      name: nameForMethod(~method=envelope.method, ~params),
    },
    metadata: params->Option.flatMap(params => params.metadata),
    clientCapabilities: metadata->Option.flatMap(metadata => metadata.clientCapabilities),
  }
}
