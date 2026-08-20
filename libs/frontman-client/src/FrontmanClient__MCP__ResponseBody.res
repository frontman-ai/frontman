module WebStreams = FrontmanBindings.WebStreams

type readError = BodyTooLarge | ReadFailed(string)

type timedRead<'value> =
  | Read(WebStreams.readResult<'value>)
  | TimedOut
  | Cancelled

type timeoutId

let maxBytes = 12582912
let maxJsonDepth = 64
let idleTimeoutMs = 60000

@val external setTimeout: (unit => unit, int) => timeoutId = "setTimeout"
@val external clearTimeout: timeoutId => unit = "clearTimeout"
@val @scope("performance") external monotonicNow: unit => float = "now"

@get external byteLength: Uint8Array.t => int = "byteLength"
@send external charAt: (string, int) => string = "charAt"
type decoderOptions = {@live fatal: bool}
@new external makeStrictDecoder: (string, decoderOptions) => WebStreams.textDecoder = "TextDecoder"
@new external emptyBytes: int => Uint8Array.t = "Uint8Array"

let cancelWithoutWaiting = (reader, reason) => {
  reader->WebStreams.cancelReader(reason)->Promise.catch(_ => Promise.resolve())->ignore
}

let readBeforeDeadline = (
  reader,
  deadline,
  ~signal: option<WebAPI.EventAPI.abortSignal>=?,
): promise<timedRead<'value>> => {
  let cancel = outcome => {
    switch outcome {
    | TimedOut => cancelWithoutWaiting(reader, "MCP response idle timeout exceeded")
    | Cancelled => cancelWithoutWaiting(reader, "MCP request cancelled")
    | Read(_) => ()
    }
  }
  switch (signal->Option.mapOr(false, value => value.aborted), monotonicNow() > deadline) {
  | (true, _) =>
    cancel(Cancelled)
    Promise.resolve(Cancelled)
  | (false, true) =>
    cancel(TimedOut)
    Promise.resolve(TimedOut)
  | (false, false) =>
    Promise.make((resolve, reject) => {
      let settled = ref(false)
      let timeoutOwner = ref(None)
      let abortListener = ref(None)
      let cleanup = () => {
        timeoutOwner.contents->Option.forEach(clearTimeout)
        abortListener.contents->Option.forEach(listener =>
          signal->Option.forEach(
            value => value->WebAPI.AbortSignal.removeEventListener(Abort, listener),
          )
        )
      }
      let settle = outcome => {
        switch settled.contents {
        | true => ()
        | false =>
          settled := true
          cleanup()
          cancel(outcome)
          resolve(outcome)
        }
      }
      let fail = exn => {
        switch settled.contents {
        | true => ()
        | false =>
          settled := true
          cleanup()
          reject(exn)
        }
      }
      let onAbort = _event => settle(Cancelled)
      abortListener := Some(onAbort)
      signal->Option.forEach(value => value->WebAPI.AbortSignal.addEventListener(Abort, onAbort))
      let remaining = deadline -. monotonicNow()
      timeoutOwner :=
        Some(
          setTimeout(
            () => settle(TimedOut),
            switch remaining > 0.0 {
            | true => remaining->Float.toInt + 1
            | false => 1
            },
          ),
        )
      reader
      ->WebStreams.readChunk
      ->Promise.then(result => {
        switch monotonicNow() <= deadline {
        | true => settle(Read(result))
        | false => settle(TimedOut)
        }
        Promise.resolve()
      })
      ->Promise.catch(exn => {
        fail(exn)
        Promise.resolve()
      })
      ->ignore
      switch signal->Option.mapOr(false, value => value.aborted) {
      | true => settle(Cancelled)
      | false => ()
      }
    })
  }
}

let exceedsDepth = source => {
  let rec loop = (~index, ~depth, ~quoted, ~escaped) =>
    switch index >= source->String.length {
    | true => false
    | false =>
      let character = source->charAt(index)
      switch (quoted, escaped, character) {
      | (true, true, _) => loop(~index=index + 1, ~depth, ~quoted, ~escaped=false)
      | (true, false, "\\") => loop(~index=index + 1, ~depth, ~quoted, ~escaped=true)
      | (_, false, "\"") => loop(~index=index + 1, ~depth, ~quoted=!quoted, ~escaped=false)
      | (false, false, "{") | (false, false, "[") =>
        depth == maxJsonDepth ? true : loop(~index=index + 1, ~depth=depth + 1, ~quoted, ~escaped)
      | (false, false, "}") | (false, false, "]") =>
        loop(~index=index + 1, ~depth=depth - 1, ~quoted, ~escaped)
      | _ => loop(~index=index + 1, ~depth, ~quoted, ~escaped)
      }
    }
  loop(~index=0, ~depth=0, ~quoted=false, ~escaped=false)
}

let readText = async (
  response: WebAPI.FetchAPI.response,
  ~signal: option<WebAPI.EventAPI.abortSignal>=?,
): result<string, readError> =>
  switch response.body->Null.toOption {
  | None => Error(ReadFailed("No response body"))
  | Some(body) =>
    let reader = body->WebAPI.ReadableStream.getReader
    let decoder = makeStrictDecoder("utf-8", {fatal: true})
    let textChunks = []
    let bytesRead = ref(0)
    let doneReading = ref(false)
    let failure = ref(None)
    let idleDeadline = ref(monotonicNow() +. idleTimeoutMs->Int.toFloat)
    let result = try {
      while !doneReading.contents && failure.contents->Option.isNone {
        switch await readBeforeDeadline(reader, idleDeadline.contents, ~signal?) {
        | TimedOut => failure := Some(ReadFailed("MCP response timed out"))
        | Cancelled => failure := Some(ReadFailed("Request cancelled"))
        | Read(chunk) if chunk.done =>
          textChunks->Array.push(decoder->WebStreams.decode(emptyBytes(0)))->ignore
          doneReading := true
        | Read(chunk) =>
          idleDeadline := monotonicNow() +. idleTimeoutMs->Int.toFloat
          let bytes = chunk.value->Nullable.toOption->Option.getOrThrow
          switch bytesRead.contents > maxBytes - bytes->byteLength {
          | true =>
            cancelWithoutWaiting(reader, "MCP response exceeds byte limit")
            failure := Some(BodyTooLarge)
          | false =>
            bytesRead := bytesRead.contents + bytes->byteLength
            textChunks
            ->Array.push(decoder->WebStreams.decodeWithOptions(bytes, {"stream": true}))
            ->ignore
          }
        }
      }
      failure.contents->Option.mapOr(Ok(textChunks->Array.join("")), error => Error(error))
    } catch {
    | exn =>
      Error(
        ReadFailed(
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("Response read failed"),
        ),
      )
    }
    reader->WebStreams.releaseReader
    result
  }
