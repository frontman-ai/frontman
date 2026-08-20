module NodeHttp = FrontmanBindings.NodeHttp
module WebStreams = FrontmanBindings.WebStreams
module RawHeaders = FrontmanCore__MCP__RawHeaders

type gateResult<'context> = Granted('context) | Denied(WebAPI.FetchAPI.response)

type adaptedRequest<'context> = {
  request: WebAPI.FetchAPI.request,
  rawHeaders: RawHeaders.t,
  context: 'context,
  signal: WebAPI.EventAPI.abortSignal,
}

type outcome = Passed | Responded | Cancelled | TimedOut
type terminalReason = Active | Disconnected | DeadlineExceeded
type raced<'value> = Completed('value) | Stopped(terminalReason)
type timeoutId

type streamingRequestInit = {
  @live
  method: string,
  @live
  headers: WebAPI.HeadersInit.t,
  @live
  body: WebAPI.BodyInit.t,
  @live
  duplex: string,
  @live
  signal: WebAPI.EventAPI.abortSignal,
}

type lifecycle = {
  terminalReason: ref<terminalReason>,
  absoluteDeadline: option<float>,
  controller: WebAPI.EventAPI.abortController,
  nodeRequest: NodeHttp.incomingMessage,
  responseReader: ref<option<WebAPI.FileAPI.readableStreamReader<Uint8Array.t>>>,
  drainResolver: ref<option<bool => unit>>,
  terminalResolver: ref<option<terminalReason => unit>>,
}

@val
external setTimeout: (unit => unit, int) => timeoutId = "setTimeout"

@val
external clearTimeout: timeoutId => unit = "clearTimeout"

@val @scope("performance")
external monotonicNow: unit => float = "now"

external streamingRequestInitAsRequestInit: streamingRequestInit => WebAPI.FetchAPI.requestInit =
  "%identity"

@send
external forEachHeader: (WebAPI.FetchAPI.headers, (string, string) => unit) => unit = "forEach"

let headerSnapshot = (rawHeaders: RawHeaders.t): WebAPI.FetchAPI.headers => {
  let headers = WebAPI.Headers.make()
  rawHeaders->Array.forEach(field =>
    headers->WebAPI.Headers.append(~name=field.name, ~value=field.value)
  )
  headers
}

let requestUrl = (~nodeRequest, ~rawHeaders): string => {
  let host = switch rawHeaders->RawHeaders.values(~name="Host") {
  | [host] if host != "" => host
  | [] => failwith("Node request is missing a physical Host header")
  | [_] => failwith("Node request has an empty physical Host header")
  | _ => failwith("Node request has duplicate physical Host headers")
  }
  `http://${host}${nodeRequest->NodeHttp.url}`
}

let abortWork = (lifecycle: lifecycle): unit => {
  WebAPI.AbortController.abort(lifecycle.controller)
  switch lifecycle.responseReader.contents {
  | None => ()
  | Some(reader) =>
    reader
    ->WebStreams.cancelReader("Node response stopped")
    ->Promise.catch(error => {
      Console.error2("Frontman response reader cancellation failed:", error)
      Promise.resolve()
    })
    ->ignore
  }
  switch lifecycle.drainResolver.contents {
  | Some(resolve) =>
    lifecycle.drainResolver := None
    resolve(false)
  | None => ()
  }
}

let stop = (lifecycle: lifecycle, reason: terminalReason): unit => {
  switch lifecycle.terminalReason.contents {
  | Disconnected | DeadlineExceeded => ()
  | Active =>
    lifecycle.terminalReason := reason
    switch lifecycle.terminalResolver.contents {
    | Some(resolve) =>
      lifecycle.terminalResolver := None
      resolve(reason)
    | None => ()
    }
    lifecycle->abortWork
    switch reason {
    | Disconnected =>
      switch lifecycle.nodeRequest->NodeHttp.destroyed {
      | true => ()
      | false => lifecycle.nodeRequest->NodeHttp.destroy
      }
    | Active | DeadlineExceeded => ()
    }
  }
}

let raceTerminal = async (
  work: promise<'value>,
  terminal: promise<terminalReason>,
  lifecycle: lifecycle,
): raced<'value> => {
  let result = try {
    await Promise.race([
      work->Promise.then(value => Promise.resolve(Completed(value))),
      terminal->Promise.then(reason => Promise.resolve(Stopped(reason))),
    ])
  } catch {
  | exn =>
    switch lifecycle.terminalReason.contents {
    | Disconnected as reason | DeadlineExceeded as reason => Stopped(reason)
    | Active => throw(exn)
    }
  }
  switch (result, lifecycle.absoluteDeadline) {
  | (Completed(_), Some(deadline)) if monotonicNow() > deadline =>
    stop(lifecycle, DeadlineExceeded)
    Stopped(DeadlineExceeded)
  | _ => result
  }
}

let makeWebRequest = (
  ~nodeRequest,
  ~url,
  ~headers,
  ~signal: WebAPI.EventAPI.abortSignal,
): WebAPI.FetchAPI.request => {
  let method = nodeRequest->NodeHttp.method
  switch method->String.toUpperCase {
  | "GET" | "HEAD" =>
    WebAPI.Request.fromURL(
      url,
      ~init={method, headers: headers->WebAPI.HeadersInit.fromHeaders, signal: Null.make(signal)},
    )
  | _ =>
    switch nodeRequest->NodeHttp.readableDidRead {
    | true => failwith("Node request body was consumed before streaming adaptation")
    | false =>
      let body = nodeRequest->NodeHttp.Readable.toWeb->WebAPI.BodyInit.fromReadableStream
      let init = streamingRequestInitAsRequestInit({
        method,
        headers: headers->WebAPI.HeadersInit.fromHeaders,
        body,
        duplex: "half",
        signal,
      })
      WebAPI.Request.fromURL(url, ~init)
    }
  }
}

let writeHeaders = (
  ~webResponse: WebAPI.FetchAPI.response,
  ~nodeResponse: NodeHttp.serverResponse,
): unit => {
  nodeResponse->NodeHttp.setStatusCode(webResponse.status)
  webResponse.headers->forEachHeader((value, name) => nodeResponse->NodeHttp.setHeader(name, value))
}

let waitForDrain = async (~nodeResponse, ~lifecycle): bool => {
  let onDrain = ref(None)
  let drained = await Promise.make((resolve, _reject) => {
    let listener = () => {
      lifecycle.drainResolver := None
      resolve(true)
    }
    onDrain := Some(listener)
    lifecycle.drainResolver := Some(resolve)
    nodeResponse->NodeHttp.onEvent("drain", listener)
  })
  nodeResponse->NodeHttp.removeEventListener("drain", onDrain.contents->Option.getOrThrow)
  drained
}

let rec pumpResponse = async (~reader, ~nodeResponse, ~lifecycle, ~onCommitted): unit => {
  switch lifecycle.terminalReason.contents {
  | Disconnected => ()
  | Active | DeadlineExceeded =>
    let result = try {
      Some(await reader->WebStreams.readChunk)
    } catch {
    | exn =>
      switch lifecycle.terminalReason.contents {
      | Disconnected | DeadlineExceeded => None
      | Active => throw(exn)
      }
    }
    switch result {
    | None => ()
    | Some({done: true}) => ()
    | Some({done: false, value}) =>
      let writable = switch value->Nullable.toOption {
      | Some(chunk) =>
        let writable = nodeResponse->NodeHttp.writeUint8Array(chunk)
        onCommitted()
        writable
      | None => true
      }
      let continue = switch writable {
      | true => true
      | false => await waitForDrain(~nodeResponse, ~lifecycle)
      }
      switch continue {
      | true => await pumpResponse(~reader, ~nodeResponse, ~lifecycle, ~onCommitted)
      | false => ()
      }
    }
  }
}

let writeResponse = async (~webResponse, ~nodeResponse, ~lifecycle, ~onCommitted) => {
  writeHeaders(~webResponse, ~nodeResponse)
  switch webResponse.body->Null.toOption {
  | None => ()
  | Some(body) =>
    let reader = body->WebAPI.ReadableStream.getReader
    lifecycle.responseReader := Some(reader)
    try {
      await pumpResponse(~reader, ~nodeResponse, ~lifecycle, ~onCommitted)
      reader->WebStreams.releaseReader
      lifecycle.responseReader := None
    } catch {
    | exn =>
      reader->WebStreams.releaseReader
      lifecycle.responseReader := None
      throw(exn)
    }
  }
}

let handle = async (
  ~nodeRequest: NodeHttp.incomingMessage,
  ~nodeResponse: NodeHttp.serverResponse,
  ~absoluteTimeoutMs: option<int>=?,
  ~gate: (WebAPI.FetchAPI.headers, RawHeaders.t) => promise<gateResult<'context>>,
  ~dispatch: adaptedRequest<'context> => promise<option<WebAPI.FetchAPI.response>>,
): outcome => {
  let rawHeaders = nodeRequest->NodeHttp.rawHeaders->RawHeaders.fromFlatArray
  let url = requestUrl(~nodeRequest, ~rawHeaders)
  let headers = headerSnapshot(rawHeaders)
  let controller = WebAPI.AbortController.make()
  let absoluteDeadline =
    absoluteTimeoutMs->Option.map(timeoutMs => monotonicNow() +. timeoutMs->Int.toFloat)
  let terminalResolver = ref(None)
  let terminal = Promise.make((resolve, _reject) => terminalResolver := Some(resolve))
  let lifecycle = {
    terminalReason: ref(Active),
    absoluteDeadline,
    controller,
    nodeRequest,
    responseReader: ref(None),
    drainResolver: ref(None),
    terminalResolver,
  }
  let onCancelled = () => stop(lifecycle, Disconnected)
  nodeRequest->NodeHttp.onEvent("aborted", onCancelled)
  nodeResponse->NodeHttp.onEvent("close", onCancelled)
  let deadlineTimer =
    absoluteTimeoutMs->Option.map(timeoutMs =>
      setTimeout(() => stop(lifecycle, DeadlineExceeded), timeoutMs + 1)
    )
  let clearDeadline = () => deadlineTimer->Option.forEach(clearTimeout)
  let cleanup = () => {
    clearDeadline()
    nodeRequest->NodeHttp.removeEventListener("aborted", onCancelled)
    nodeResponse->NodeHttp.removeEventListener("close", onCancelled)
  }

  try {
    let gateResult = await raceTerminal(gate(headers, rawHeaders), terminal, lifecycle)
    let result = switch gateResult {
    | Stopped(Disconnected) => Cancelled
    | Stopped(DeadlineExceeded) => TimedOut
    | Stopped(Active) => failwith("Active lifecycle cannot stop work")
    | Completed(Denied(response)) =>
      switch lifecycle.terminalReason.contents {
      | Disconnected => Cancelled
      | DeadlineExceeded => TimedOut
      | Active =>
        await writeResponse(
          ~webResponse=response,
          ~nodeResponse,
          ~lifecycle,
          ~onCommitted=clearDeadline,
        )
        switch lifecycle.terminalReason.contents {
        | Disconnected => Cancelled
        | DeadlineExceeded => TimedOut
        | Active => Responded
        }
      }
    | Completed(Granted(context)) =>
      switch lifecycle.terminalReason.contents {
      | Disconnected => Cancelled
      | DeadlineExceeded => TimedOut
      | Active =>
        let request = makeWebRequest(~nodeRequest, ~url, ~headers, ~signal=controller.signal)
        let response = await raceTerminal(
          dispatch({request, rawHeaders, context, signal: controller.signal}),
          terminal,
          lifecycle,
        )
        switch response {
        | Stopped(Disconnected) => Cancelled
        | Stopped(DeadlineExceeded) => TimedOut
        | Stopped(Active) => failwith("Active lifecycle cannot stop work")
        | Completed(None) => Passed
        | Completed(Some(response)) =>
          await writeResponse(
            ~webResponse=response,
            ~nodeResponse,
            ~lifecycle,
            ~onCommitted=clearDeadline,
          )
          switch lifecycle.terminalReason.contents {
          | Disconnected => Cancelled
          | DeadlineExceeded => TimedOut
          | Active => Responded
          }
        }
      }
    }
    cleanup()
    switch result {
    | Responded =>
      clearDeadline()
      nodeResponse->NodeHttp.end
    | TimedOut =>
      nodeResponse->NodeHttp.setStatusCode(408)
      nodeResponse->NodeHttp.end
    | Passed | Cancelled => ()
    }
    result
  } catch {
  | exn =>
    cleanup()
    throw(exn)
  }
}
