// Helper to resolve source locations via the dedicated API endpoint

let resolve = async (sourceLocation: Client__Types.SourceLocation.t): result<
  Client__Types.SourceLocation.t,
  string,
> => {
  let baseUrl = {
    let location = WebAPI.Global.location
    `${location.protocol}//${location.host}`
  }
  let url = `${baseUrl}/frontman/resolve-source-location`

  let requestBody = {
    "componentName": sourceLocation.componentName->Option.getOr(""),
    "file": sourceLocation.file,
    "line": sourceLocation.line,
    "column": sourceLocation.column,
  }

  try {
    let response = await WebAPI.Global.fetch(
      url,
      ~init={
        method: "POST",
        headers: WebAPI.HeadersInit.fromDict(
          Dict.fromArray([("Content-Type", "application/json")]),
        ),
        body: WebAPI.BodyInit.fromString(JSON.stringifyAny(requestBody)->Option.getOr("{}")),
      },
    )

    if !response.ok {
      Error(`HTTP ${response.status->Int.toString}: ${response.statusText}`)
    } else {
      let json = await response->WebAPI.Response.json
      let resultObj = json->JSON.Decode.object

      switch resultObj {
      | Some(obj) =>
        let componentName =
          obj
          ->Dict.get("componentName")
          ->Option.flatMap(JSON.Decode.string)
          ->Option.orElse(sourceLocation.componentName)
        let file =
          obj
          ->Dict.get("file")
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr(sourceLocation.file)
        let line =
          obj
          ->Dict.get("line")
          ->Option.flatMap(JSON.Decode.float)
          ->Option.mapOr(sourceLocation.line, Float.toInt)
        let column =
          obj
          ->Dict.get("column")
          ->Option.flatMap(JSON.Decode.float)
          ->Option.mapOr(sourceLocation.column, Float.toInt)

        Ok(
          (
            {
              componentName,
              tagName: sourceLocation.tagName,
              file,
              line,
              column,
              parent: sourceLocation.parent, // Keep parent as-is for now
              componentProps: sourceLocation.componentProps,
            }: Client__Types.SourceLocation.t
          ),
        )
      | None => Error("Invalid response format")
      }
    }
  } catch {
  | exn =>
    let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Failed to resolve source location: ${msg}`)
  }
}
