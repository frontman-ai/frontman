// SSE (Server-Sent Events) Parser
// Parses SSE stream from fetch response, returns first result event or error.

module WebStreams = FrontmanBindings.WebStreams

type eventType = [#progress | #result | #error | #unknown]

type sseEvent = {
  eventType: eventType,
  data: string,
}

let parseEventType = (s: string): eventType => {
  switch s {
  | "progress" => #progress
  | "result" => #result
  | "error" => #error
  | _ => #unknown
  }
}

// SSE spec: multiple data: lines concatenate with newlines
let parseEventBlock = (block: string): option<sseEvent> => {
  let lines = block->String.split("\n")

  let eventTypeStr =
    lines
    ->Array.find(line => line->String.startsWith("event:"))
    ->Option.map(line => line->String.slice(~start=6, ~end=line->String.length)->String.trim)
    ->Option.getOr("")

  let data =
    lines
    ->Array.filter(line => line->String.startsWith("data:"))
    ->Array.map(line => line->String.slice(~start=5, ~end=line->String.length)->String.trim)
    ->Array.join("\n")

  if data == "" {
    None
  } else {
    Some({eventType: parseEventType(eventTypeStr), data})
  }
}

// Process a single SSE event, returns Some(result) if terminal (result/error)
let processEvent = (event: sseEvent, ~onProgress: option<string => unit>): option<
  result<JSON.t, string>,
> => {
  switch event.eventType {
  | #progress =>
    onProgress->Option.forEach(cb => cb(event.data))
    None
  | #result =>
    let parsed = try {
      Ok(JSON.parseOrThrow(event.data))
    } catch {
    | exn =>
      let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("unknown")
      Error(`Failed to parse result JSON: ${msg}`)
    }
    Some(parsed)
  | #error => Some(Error(event.data))
  | #unknown => None
  }
}

// Extract error message from exception
let exnMessage = (exn: exn): string => {
  exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("unknown")
}

// Process complete blocks, return first terminal result or None
let processBlocks = (blocks: array<string>, ~onProgress: option<string => unit>): option<
  result<JSON.t, string>,
> => {
  blocks->Array.reduceWithIndex(None, (acc, block, _i) => {
    switch acc {
    | Some(_) => acc
    | None =>
      switch parseEventBlock(block) {
      | None => None
      | Some(event) => processEvent(event, ~onProgress)
      }
    }
  })
}

// Read SSE stream, return first result or error
let readStream = async (
  response: WebAPI.FetchAPI.response,
  ~onProgress: option<string => unit>=?,
): result<JSON.t, string> => {
  switch response.body->Null.toOption {
  | None => Error("No response body")
  | Some(body) =>
    let reader = body->WebAPI.ReadableStream.getReader
    let decoder = WebStreams.makeTextDecoder()
    let incompleteChunk = ref("")
    let result = ref(None)

    try {
      while result.contents->Option.isNone {
        let chunk = await reader->WebStreams.readChunk

        if chunk.done {
          result := Some(Error("Stream ended without result"))
        } else {
          chunk.value
          ->Nullable.toOption
          ->Option.map(bytes => {
            let text = decoder->WebStreams.decodeWithOptions(bytes, {"stream": true})
            let fullText = incompleteChunk.contents ++ text
            let parts = fullText->String.split("\n\n")
            let partsCount = parts->Array.length

            incompleteChunk := parts->Array.getUnsafe(partsCount - 1)

            let completeBlocks = parts->Array.slice(~start=0, ~end=partsCount - 1)
            result := processBlocks(completeBlocks, ~onProgress)
          })
          ->Option.getOr()
        }
      }

      result.contents->Option.getOr(Error("Stream ended without result"))
    } catch {
    | exn => Error(`Stream read error: ${exnMessage(exn)}`)
    }
  }
}
