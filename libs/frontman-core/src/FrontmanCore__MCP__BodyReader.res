module BodyDecoder = FrontmanCore__MCP__BodyDecoder
module WebStreams = FrontmanBindings.WebStreams

type readError =
  | InvalidContentLength
  | BodyTooLarge
  | BodyTooFragmented
  | BodyTimedOut

type timedRead<'value> =
  | Read(WebStreams.readResult<'value>)
  | TimedOut

type timeoutId

let contentLengthPattern = /^\d+$/
let maxChunks = 4096
let idleTimeoutMs = 60000

@val
external setTimeout: (unit => unit, int) => timeoutId = "setTimeout"

@val
external clearTimeout: timeoutId => unit = "clearTimeout"

@val @scope("performance")
external monotonicNow: unit => float = "now"

@new
external makeBytes: int => Uint8Array.t = "Uint8Array"

@get
external byteLength: Uint8Array.t => int = "byteLength"

@send
external setBytes: (Uint8Array.t, Uint8Array.t, int) => unit = "set"

@send
external sliceBytes: (Uint8Array.t, int, int) => Uint8Array.t = "slice"

let validateContentLength = headers => {
  switch headers->WebAPI.Headers.get("Content-Length")->Null.toOption {
  | None => Ok()
  | Some(value) =>
    switch contentLengthPattern->RegExp.test(value) {
    | false => Error(InvalidContentLength)
    | true =>
      switch Float.fromString(value) {
      | Some(length) if length <= BodyDecoder.maxBodyBytes->Int.toFloat => Ok()
      | Some(_) => Error(BodyTooLarge)
      | None => Error(InvalidContentLength)
      }
    }
  }
}

let reportRejection = (promise, message) =>
  promise
  ->Promise.catch(exn => {
    exn->ignore
    Console.error(message)
    Promise.resolve()
  })
  ->ignore

let cancelAfterTimeout = reader =>
  reader
  ->WebStreams.cancelReader("request body idle timeout exceeded")
  ->reportRejection("MCP body reader cancellation failed after timeout")

let readBeforeDeadline = async (reader, deadline) => {
  let remaining = deadline -. monotonicNow()
  switch remaining < 0.0 {
  | true =>
    reader->cancelAfterTimeout
    TimedOut
  | false =>
    let timeoutId = ref(None)
    let timeout = Promise.make((resolve, _reject) => {
      timeoutId.contents = Some(setTimeout(() => resolve(TimedOut), remaining->Float.toInt + 1))
    })
    let read = async () => Read(await reader->WebStreams.readChunk)
    let pendingRead = read()

    try {
      let result = await Promise.race([pendingRead, timeout])
      clearTimeout(timeoutId.contents->Option.getOrThrow)
      switch result {
      | Read(_) if monotonicNow() <= deadline => result
      | Read(_) =>
        reader->cancelAfterTimeout
        TimedOut
      | TimedOut =>
        reader->cancelAfterTimeout
        try {
          let _ = await pendingRead
        } catch {
        | exn =>
          exn->ignore
          Console.error("MCP body reader pending read failed after timeout")
        }
        TimedOut
      }
    } catch {
    | exn =>
      clearTimeout(timeoutId.contents->Option.getOrThrow)
      throw(exn)
    }
  }
}

let read = async (
  ~headers: WebAPI.FetchAPI.headers,
  ~body: WebAPI.FileAPI.readableStream<Uint8Array.t>,
): result<Uint8Array.t, readError> => {
  switch validateContentLength(headers) {
  | Error(_) as error => error
  | Ok() =>
    let reader = body->WebAPI.ReadableStream.getReader
    let bytes = makeBytes(BodyDecoder.maxBodyBytes)
    let length = ref(0)
    let chunkCount = ref(0)
    let idleDeadline = ref(monotonicNow() +. idleTimeoutMs->Int.toFloat)

    let rec readNext = async () => {
      switch await readBeforeDeadline(reader, idleDeadline.contents) {
      | TimedOut => Error(BodyTimedOut)
      | Read(result) if result.done => Ok(bytes->sliceBytes(0, length.contents))
      | Read(result) =>
        let chunk = result.value->Nullable.toOption->Option.getOrThrow
        chunkCount.contents = chunkCount.contents + 1
        switch chunkCount.contents > maxChunks {
        | true =>
          await reader->WebStreams.cancelReader("request body chunk limit exceeded")
          Error(BodyTooFragmented)
        | false =>
          let chunkLength = chunk->byteLength
          switch chunkLength > BodyDecoder.maxBodyBytes - length.contents {
          | true =>
            await reader->WebStreams.cancelReader("request body limit exceeded")
            Error(BodyTooLarge)
          | false =>
            bytes->setBytes(chunk, length.contents)
            length.contents = length.contents + chunkLength
            switch chunkLength > 0 {
            | true => idleDeadline.contents = monotonicNow() +. idleTimeoutMs->Int.toFloat
            | false => ()
            }
            await readNext()
          }
        }
      }
    }

    try {
      let result = await readNext()
      reader->WebStreams.releaseReader
      result
    } catch {
    | exn =>
      reader->WebStreams.releaseReader
      throw(exn)
    }
  }
}
