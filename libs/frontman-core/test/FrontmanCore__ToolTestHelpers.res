module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP

let text = (result: MCP.CallToolResult.t): result<string, string> => {
  let json = result->S.reverseConvertToJsonOrThrow(MCP.callToolResultSchema)
  let obj = json->JSON.Decode.object->Option.getOrThrow
  let isError = obj->Dict.get("isError")->Option.flatMap(JSON.Decode.bool)->Option.getOr(false)
  let content = obj->Dict.get("content")->Option.flatMap(JSON.Decode.array)->Option.getOrThrow
  let text = switch content->Array.get(0)->Option.flatMap(JSON.Decode.object) {
  | Some(block) => block->Dict.get("text")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
  | None => ""
  }

  switch isError {
  | true => Error(text)
  | false => Ok(text)
  }
}

let decode = (result: MCP.CallToolResult.t, schema: S.t<'a>): result<'a, string> => {
  switch result->text {
  | Error(msg) => Error(msg)
  | Ok(text) =>
    try {
      Ok(text->JSON.parseOrThrow->S.parseOrThrow(schema))
    } catch {
    | _ => Error("Failed to decode tool result")
    }
  }
}

let execute = async (fn, ctx, input, schema) => {
  let result = await fn(ctx, input)
  decode(result, schema)
}
