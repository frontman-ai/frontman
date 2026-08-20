module Types = FrontmanClient__MCP__Types
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module WebStreams = FrontmanBindings.WebStreams
module ResponseBody = FrontmanClient__MCP__ResponseBody

type message =
  | Notification(JSON.t)
  | Terminal(JSON.t)

let parseFrame = block => {
  let data =
    block
    ->String.split("\n")
    ->Array.map(line => line->String.endsWith("\r") ? line->String.slice(~start=0, ~end=-1) : line)
    ->Array.filterMap(line =>
      switch line->String.startsWith("data:") {
      | false => None
      | true =>
        let value = line->String.slice(~start=5)
        Some(value->String.startsWith(" ") ? value->String.slice(~start=1) : value)
      }
    )
    ->Array.join("\n")
  data == "" ? None : Some(data)
}

let classify = data => {
  switch ResponseBody.exceedsDepth(data) {
  | true => Error("MCP SSE message exceeds the JSON depth limit")
  | false =>
    try {
      let json = JSON.parseOrThrow(data)
      json->S.parseOrThrow(~to=Types.StreamableHttpSseMessage.schema)->ignore
      try {
        json->S.parseOrThrow(~to=JsonRpc.Wire.notificationSchema)->ignore
        Ok(Notification(json))
      } catch {
      | S.Exn(_) => Ok(Terminal(json))
      | exn => throw(exn)
      }
    } catch {
    | S.Exn(_) => Error("Invalid MCP SSE message")
    | exn =>
      Error(
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Invalid MCP SSE JSON"),
      )
    }
  }
}

let takeBlocks = buffer => {
  let rec loop = (remaining, blocks) => {
    let lf = remaining->String.indexOf("\n\n")
    let crlf = remaining->String.indexOf("\r\n\r\n")
    let boundary = switch (lf, crlf) {
    | (-1, -1) => None
    | (-1, index) => Some((index, 4))
    | (index, -1) => Some((index, 2))
    | (left, right) => left < right ? Some((left, 2)) : Some((right, 4))
    }
    switch boundary {
    | None => (blocks, remaining)
    | Some((index, length)) =>
      loop(
        remaining->String.slice(~start=index + length),
        Array.concat(blocks, [remaining->String.slice(~start=0, ~end=index)]),
      )
    }
  }
  loop(buffer, [])
}

let consumeBlocks = (text, blockParts, suffix, onBlock) => {
  let source = suffix.contents ++ text
  suffix := ""
  let cursor = ref(0)
  let blockStart = ref(0)
  while cursor.contents < source->String.length {
    let boundaryLength = switch source->ResponseBody.charAt(cursor.contents) {
    | "\n" if source->ResponseBody.charAt(cursor.contents + 1) == "\n" => 2
    | "\r"
      if source->ResponseBody.charAt(cursor.contents + 1) == "\n" &&
      source->ResponseBody.charAt(cursor.contents + 2) == "\r" &&
      source->ResponseBody.charAt(cursor.contents + 3) == "\n" => 4
    | _ => 0
    }
    switch boundaryLength {
    | 0 => cursor := cursor.contents + 1
    | length =>
      blockParts.contents
      ->Array.push(source->String.slice(~start=blockStart.contents, ~end=cursor.contents))
      ->ignore
      onBlock(blockParts.contents->Array.join(""))
      blockParts := []
      cursor := cursor.contents + length
      blockStart := cursor.contents
    }
  }
  let suffixStart = source->String.length - 3
  let split = suffixStart > blockStart.contents ? suffixStart : blockStart.contents
  switch split > blockStart.contents {
  | true =>
    blockParts.contents
    ->Array.push(source->String.slice(~start=blockStart.contents, ~end=split))
    ->ignore
  | false => ()
  }
  suffix := source->String.slice(~start=split)
}

let readStream = async (
  response: WebAPI.FetchAPI.response,
  ~onNotification: option<JSON.t => unit>=?,
  ~signal: option<WebAPI.EventAPI.abortSignal>=?,
): result<JSON.t, string> => {
  switch response.body->Null.toOption {
  | None => Error("No response body")
  | Some(body) =>
    let reader = body->WebAPI.ReadableStream.getReader
    let decoder = ResponseBody.makeStrictDecoder("utf-8", {fatal: true})
    let blockParts = ref([])
    let suffix = ref("")
    let bytesRead = ref(0)
    let terminal = ref(None)
    let failure = ref(None)
    let doneReading = ref(false)
    let idleDeadline = ref(ResponseBody.monotonicNow() +. ResponseBody.idleTimeoutMs->Int.toFloat)

    let handleBlock = block =>
      switch (terminal.contents, failure.contents, parseFrame(block)) {
      | (Some(_), _, Some(_)) => failure := Some("SSE stream contains multiple terminal responses")
      | (_, Some(_), _) | (_, _, None) => ()
      | (None, None, Some(data)) =>
        switch classify(data) {
        | Error(message) => failure := Some(message)
        | Ok(Notification(json)) => onNotification->Option.forEach(callback => callback(json))
        | Ok(Terminal(json)) => terminal := Some(json)
        }
      }

    let result = try {
      while (
        !doneReading.contents && terminal.contents->Option.isNone && failure.contents->Option.isNone
      ) {
        switch await ResponseBody.readBeforeDeadline(reader, idleDeadline.contents, ~signal?) {
        | TimedOut => failure := Some("MCP response timed out")
        | Cancelled => failure := Some("Request cancelled")
        | Read(chunk) if chunk.done =>
          consumeBlocks(
            decoder->WebStreams.decode(ResponseBody.emptyBytes(0)),
            blockParts,
            suffix,
            handleBlock,
          )
          blockParts.contents->Array.push(suffix.contents)->ignore
          handleBlock(blockParts.contents->Array.join(""))
          doneReading := true
        | Read(chunk) =>
          idleDeadline := ResponseBody.monotonicNow() +. ResponseBody.idleTimeoutMs->Int.toFloat
          let bytes = chunk.value->Nullable.toOption->Option.getOrThrow
          switch bytesRead.contents > ResponseBody.maxBytes - bytes->ResponseBody.byteLength {
          | true =>
            ResponseBody.cancelWithoutWaiting(reader, "MCP response exceeds byte limit")
            failure := Some("MCP response exceeds the byte limit")
          | false =>
            bytesRead := bytesRead.contents + bytes->ResponseBody.byteLength
            consumeBlocks(
              decoder->WebStreams.decodeWithOptions(bytes, {"stream": true}),
              blockParts,
              suffix,
              handleBlock,
            )
          }
        }
      }

      switch (failure.contents, terminal.contents) {
      | (Some(message), _) => Error(message)
      | (None, Some(json)) => Ok(json)
      | (None, None) => Error("SSE stream ended without a terminal response")
      }
    } catch {
    | exn =>
      switch signal {
      | Some(value) if value.aborted =>
        ResponseBody.cancelWithoutWaiting(reader, "MCP request cancelled")
        Error("Request cancelled")
      | Some(_) | None =>
        Error(
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("SSE stream read failed"),
        )
      }
    }
    switch terminal.contents {
    | Some(_) => ResponseBody.cancelWithoutWaiting(reader, "MCP terminal response received")
    | None => ()
    }
    reader->WebStreams.releaseReader
    result
  }
}
