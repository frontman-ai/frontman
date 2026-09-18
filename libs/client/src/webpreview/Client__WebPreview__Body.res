module Log = FrontmanLogs.Logs.Make({
  let component = #WebPreviewStage
})

@react.component
let make = (~taskId, ~url, ~isActive, ~viewportStyle: option<(int, int, float)>=?) => {
  let (iframeElement, setIframeElement): (option<WebAPI.DomTypes.element>, _) = React.useState(() =>
    None
  )
  let (attachmentKey, setAttachmentKey) = React.useState(() => 0)
  let parentOrigin = (WebAPI.Window.current->WebAPI.Window.location).origin
  let frameName = {
    let config = WebAPI.URL.make(~url=parentOrigin)
    config.searchParams->WebAPI.URLSearchParams.set(~name="channel", ~value=taskId)
    config.searchParams->WebAPI.URLSearchParams.set(
      ~name="basePath",
      ~value=Client__RuntimeConfig.read().basePath,
    )
    `frontman:${config.href}`
  }
  let (iframeSrc, setIframeSrc) = React.useState(() => isActive ? url : "about:blank")
  let (hasLoaded, setHasLoaded) = React.useState(() => false)
  let trackedIframeElement = isActive ? iframeElement : None
  let location = Client__Hooks.useIFrameLocation(
    ~iframeElement=trackedIframeElement,
    ~attachmentKey,
  )
  let previewOrigin = (src: string): option<string> =>
    switch src {
    | "about:blank" => None
    | src =>
      try {
        Some(
          WebAPI.URL.make(
            ~url=src,
            ~base=(WebAPI.Window.current->WebAPI.Window.location).href,
          ).origin,
        )
      } catch {
      | exn =>
        let ctx = {"src": src}
        Log.error(~ctx, ~error=JsExn.fromException(exn), "Preview bridge origin resolution failed")
        None
      }
    }

  let targetOrigin = previewOrigin(iframeSrc)
  React.useEffect(() => {
    switch (
      isActive,
      hasLoaded,
      iframeElement->Option.flatMap(FrontmanBindings.Bindings__WebAPI.iframeElementFromElement),
      targetOrigin,
    ) {
    | (true, true, Some(iframe), Some(targetOrigin)) => {
        let runtime = Client__PreviewRuntime.make(~iframe, ~targetOrigin, ~channel=taskId)
        let publish = status => {
          let ready = status == Runtime.Open
          let (contentDocument, contentWindow) = try {
            switch ready {
            | false => (None, None)
            | true =>
              iframe.contentWindow
              ->Null.map(window => (Some(window->WebAPI.Window.document), Some(window)))
              ->Null.getOr((None, None))
            }
          } catch {
          | exn
            if exn->JsExn.fromException->Option.flatMap(JsExn.name) == Some("SecurityError") => (
              None,
              None,
            )
          | exn => throw(exn)
          }
          Client__State.Actions.setPreviewFrame(
            ~clientId=taskId,
            ~runtime=ready ? Some(runtime) : None,
            ~contentDocument,
            ~contentWindow,
          )
          switch status {
          | Runtime.Open
          | Runtime.Connecting
          | Runtime.Disconnected("Iframe reloaded")
          | Runtime.Closed("Runtime closed") => ()
          | Runtime.Disconnected(reason) | Runtime.Closed(reason) =>
            Log.error(
              ~ctx={"taskId": taskId, "targetOrigin": targetOrigin, "reason": reason},
              "Preview bridge runtime failed",
            )
          }
        }
        let removeStatusListener = Client__PreviewRuntime.onStatus(runtime, publish)
        publish(Client__PreviewRuntime.status(runtime))
        Some(
          () => {
            Client__PreviewRuntime.close(runtime)
            removeStatusListener()
          },
        )
      }
    | _ => None
    }
  }, (isActive, hasLoaded, iframeElement, targetOrigin, taskId))

  React.useEffect(() => {
    switch hasLoaded {
    | true => ()
    | false =>
      setIframeSrc(prev =>
        switch prev {
        | "about:blank" => prev
        | _ =>
          Client__BrowserUrl.removeTrailingSlash(prev) ==
            Client__BrowserUrl.removeTrailingSlash(url)
            ? prev
            : url
        }
      )
    }
    None
  }, (url, hasLoaded))

  React.useEffect(() => {
    switch isActive {
    | false => ()
    | true => setIframeSrc(prev => prev == "about:blank" ? url : prev)
    }
    None
  }, [isActive])

  React.useEffect(() => {
    switch (isActive, location) {
    | (true, Some(location)) if location->String.startsWith("http") =>
      Client__State.Actions.observePreviewUrl(~url=location)
    | _ => ()
    }
    None
  }, (location, isActive))

  let onLoad = (_e: JsxEvent.Image.t) => {
    switch iframeSrc {
    | "about:blank" => ()
    | _ =>
      setHasLoaded(_ => true)
      setAttachmentKey(prev => prev + 1)
    }
  }

  let refCallback = ReactDOM.Ref.callbackDomRef(iframe => {
    let nextIframeElement =
      iframe
      ->Nullable.toOption
      ->Option.map(FrontmanBindings.Bindings__WebAPI.elementFromReact)
    setIframeElement(_ => nextIframeElement)
    None
  })
  let iframe =
    <iframe
      className="size-full"
      name={frameName}
      src={iframeSrc}
      title={`Preview - ${taskId}`}
      onLoad
      ref={refCallback}
    />

  switch (isActive, viewportStyle) {
  | (false, _) =>
    <div className="absolute -left-[9999px] -top-[9999px] invisible size-full"> {iframe} </div>
  | (true, None) => <div className="flex-1 size-full"> {iframe} </div>
  | (true, Some((deviceWidth, deviceHeight, scale))) =>
    let widthPx = Int.toString(deviceWidth) ++ "px"
    let heightPx = Int.toString(deviceHeight) ++ "px"
    let transformStr = if scale < 1.0 {
      `scale(${Float.toFixed(scale, ~digits=4)})`
    } else {
      "none"
    }
    <div
      className="shrink-0 mt-2"
      style={
        width: widthPx,
        height: heightPx,
        transform: transformStr,
        transformOrigin: "top center",
        overflow: "hidden",
        borderRadius: "4px",
        boxShadow: "0 0 0 1px rgba(0,0,0,0.1), 0 2px 8px rgba(0,0,0,0.08)",
      }
    >
      {iframe}
    </div>
  }
}
