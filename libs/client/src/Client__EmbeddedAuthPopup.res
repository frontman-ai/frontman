let completionMessageType = "frontman.embeddedClient.authorized"
let completionMessageVersion = 1
let stateByteCount = 32
let popupCheckIntervalMs = 500
let authorizationTimeoutMs = 120000

@schema
type completionMessage = {
  @as("type")
  messageType: string,
  version: int,
  state: string,
  token: string,
}

type validateError =
  | InvalidOrigin
  | InvalidSource
  | InvalidMessage
  | InvalidState
  | InvalidType
  | InvalidVersion

type authorizeError =
  | PopupBlocked
  | PopupClosed
  | AuthorizationTimedOut

type authorization = {cancel: unit => unit}

type messageEvent = WebAPI.MessageEvent.t<JSON.t>

let frontmanOrigin = loginUrl => WebAPI.URL.make(~url=loginUrl).origin
let customerOrigin = () =>
  WebAPI.Window.current->WebAPI.Window.location->FrontmanBindings.Bindings__WebAPI.locationOrigin

let byteToHex = byte => {
  let hex = byte->Int.toString(~radix=16)
  switch hex->String.length {
  | 1 => `0${hex}`
  | _ => hex
  }
}

let generateState = () => {
  let bytes = Uint8Array.fromLength(stateByteCount)
  WebAPI.Window.current->WebAPI.Window.crypto->WebAPI.Crypto.getRandomValues(bytes)->ignore

  Belt.Array.makeBy(stateByteCount, index =>
    bytes->TypedArray.get(index)->Option.getOrThrow->byteToHex
  )->Array.join("")
}

let authorizationUrl = (~loginUrl: string, ~state: string, ~origin: string): string => {
  let url = WebAPI.URL.make(~url=loginUrl)
  url.searchParams->WebAPI.URLSearchParams.set(~name="embedded_state", ~value=state)
  url.searchParams->WebAPI.URLSearchParams.set(~name="embedded_origin", ~value=origin)
  url.href
}

let parseCompletionMessage = (data: JSON.t): result<completionMessage, validateError> => {
  try {
    Ok(S.parseOrThrow(data, ~to=completionMessageSchema))
  } catch {
  | _ => Error(InvalidMessage)
  }
}

let validateMessage = (
  ~event: messageEvent,
  ~frontmanOrigin: string,
  ~popup: WebAPI.Window.t,
  ~state: string,
): result<string, validateError> => {
  switch event.origin === frontmanOrigin {
  | false => Error(InvalidOrigin)
  | true =>
    switch event.source->Null.toOption {
    | Some(source) if source === FrontmanBindings.Bindings__WebAPI.messageSourceFromWindow(popup) =>
      switch parseCompletionMessage(event.data) {
      | Error(error) => Error(error)
      | Ok(message) if message.messageType !== completionMessageType => Error(InvalidType)
      | Ok(message) if message.version !== completionMessageVersion => Error(InvalidVersion)
      | Ok(message) if message.state !== state => Error(InvalidState)
      | Ok(message) => Ok(message.token)
      }
    | Some(_) | None => Error(InvalidSource)
    }
  }
}

let start = (
  ~loginUrl: string,
  ~onSuccess: unit => unit,
  ~onError: authorizeError => unit,
): authorization => {
  let state = generateState()
  let authUrl = authorizationUrl(~loginUrl, ~state, ~origin=customerOrigin())
  let popup =
    WebAPI.Window.current->FrontmanBindings.Bindings__WebAPI.openPopup(
      ~url=authUrl,
      ~target="frontman-embedded-auth",
      ~features="popup,width=520,height=720",
    )
  let frontmanOrigin = frontmanOrigin(loginUrl)
  let cleanedUp = ref(false)
  let messageTimer = ref(None)
  let closedTimer = ref(None)

  let removeMessageListener = ref((_handler: messageEvent => unit) => ())
  let cleanupAuthorization = ref(() => ())
  let messageHandler = (event: messageEvent) => {
    switch cleanedUp.contents {
    | true => ()
    | false =>
      switch popup->Null.toOption {
      | None => ()
      | Some(popup) =>
        switch validateMessage(~event, ~frontmanOrigin, ~popup, ~state) {
        | Ok(token) =>
          Client__EmbeddedAuth.saveToken(token)
          cleanupAuthorization.contents()
          onSuccess()
        | Error(InvalidOrigin | InvalidSource) => ()
        | Error(InvalidMessage | InvalidState | InvalidType | InvalidVersion) => ()
        }
      }
    }
  }

  removeMessageListener :=
    (
      handler =>
        WebAPI.Window.current->WebAPI.Window.removeEventListener(Custom("message"), handler)
    )

  cleanupAuthorization :=
    (
      () => {
        switch cleanedUp.contents {
        | true => ()
        | false =>
          cleanedUp := true
          removeMessageListener.contents(messageHandler)
          messageTimer.contents->Option.forEach(timer =>
            WebAPI.Window.clearTimeout(WebAPI.Window.current, timer)
          )
          closedTimer.contents->Option.forEach(timer =>
            WebAPI.Window.clearInterval(WebAPI.Window.current, timer)
          )
        }
      }
    )

  let finishWithError = error => {
    cleanupAuthorization.contents()
    onError(error)
  }

  WebAPI.Window.current->WebAPI.Window.addEventListener(Custom("message"), messageHandler)

  messageTimer :=
    Some(
      WebAPI.Window.setTimeout(
        WebAPI.Window.current,
        ~timeout=authorizationTimeoutMs,
        ~handler=() => finishWithError(AuthorizationTimedOut),
      ),
    )
  closedTimer :=
    Some(
      WebAPI.Window.setInterval2(
        WebAPI.Window.current,
        ~timeout=popupCheckIntervalMs,
        ~handler=() => {
          switch popup->Null.toOption {
          | Some(popup) if WebAPI.Window.closed(popup) => finishWithError(PopupClosed)
          | Some(_) => ()
          | None => finishWithError(PopupBlocked)
          }
        },
      ),
    )

  switch popup->Null.toOption {
  | Some(popup) if WebAPI.Window.closed(popup) => finishWithError(PopupBlocked)
  | Some(popup) => WebAPI.Window.focus(popup)
  | None => finishWithError(PopupBlocked)
  }

  {cancel: cleanupAuthorization.contents}
}
