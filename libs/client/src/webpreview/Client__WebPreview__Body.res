module Log = FrontmanLogs.Logs.Make({
  let component = #WebPreviewStage
})

@react.component
let make = (~taskId, ~url, ~isActive, ~viewportStyle: option<(int, int, float)>=?) => {
  let iframeRef: React.ref<Nullable.t<Dom.element>> = React.useRef(Nullable.null)
  let (iframeElement, setIframeElement): (option<WebAPI.DomTypes.element>, _) = React.useState(() =>
    None
  )
  let (attachmentKey, setAttachmentKey) = React.useState(() => 0)
  let parentOrigin = (WebAPI.Window.current->WebAPI.Window.location).origin
  let withPreviewBridgeParams = (src: string): string =>
    switch src {
    | "about:blank" => src
    | src =>
      try {
        let parsed = WebAPI.URL.make(
          ~url=src,
          ~base=(WebAPI.Window.current->WebAPI.Window.location).href,
        )
        parsed.searchParams->WebAPI.URLSearchParams.set(
          ~name="__frontman_parent_origin",
          ~value=parentOrigin,
        )
        parsed.searchParams->WebAPI.URLSearchParams.set(~name="__frontman_channel", ~value=taskId)
        parsed.href
      } catch {
      | exn =>
        let ctx = {"src": src}
        Console.error2("Preview bridge URL parameter injection failed", ctx)
        Log.error(
          ~ctx,
          ~error=JsExn.fromException(exn),
          "Preview bridge URL parameter injection failed",
        )
        src
      }
    }
  let (iframeSrc, setIframeSrc) = React.useState(() =>
    isActive ? url->withPreviewBridgeParams : "about:blank"
  )
  let (hasLoaded, setHasLoaded) = React.useState(() => false)
  let lastLocationRef: React.ref<option<string>> = React.useRef(None)
  let trackedIframeElement = isActive ? iframeElement : None
  let location = Client__Hooks.useIFrameLocation(
    ~iframeElement=trackedIframeElement,
    ~attachmentKey,
  )
  let readPreviewFrame = () =>
    iframeRef.current
    ->Nullable.toOption
    ->Option.map(FrontmanBindings.Bindings__WebAPI.elementFromReact)
    ->Option.flatMap(FrontmanBindings.Bindings__WebAPI.iframeElementFromElement)
    ->Option.map(iframeElement => {
      (
        WebAPI.HTMLIFrameElement.contentDocument(iframeElement),
        WebAPI.HTMLIFrameElement.contentWindow(iframeElement),
      )
    })

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
        Console.error2("Preview bridge origin resolution failed", ctx)
        Log.error(~ctx, ~error=JsExn.fromException(exn), "Preview bridge origin resolution failed")
        None
      }
    }

  React.useEffect(() => {
    switch (
      isActive,
      hasLoaded,
      iframeElement->Option.flatMap(FrontmanBindings.Bindings__WebAPI.iframeElementFromElement),
      previewOrigin(iframeSrc),
    ) {
    | (true, true, Some(iframe), Some(targetOrigin)) => {
        let runtime = Client__PreviewRuntime.make(~iframe, ~targetOrigin, ~channel=taskId)
        let removeStatusListener = Client__PreviewRuntime.onStatus(runtime, status =>
          switch status {
          | Runtime.Open => ()
          | Runtime.Connecting => ()
          | Runtime.Disconnected("Iframe reloaded") => ()
          | Runtime.Disconnected(reason) => {
              let ctx = {"taskId": taskId, "targetOrigin": targetOrigin, "reason": reason}
              Console.error2("Preview bridge runtime disconnected", ctx)
              Log.error(~ctx, "Preview bridge runtime disconnected")
            }
          | Runtime.Closed("Runtime closed") => ()
          | Runtime.Closed(reason) => {
              let ctx = {"taskId": taskId, "targetOrigin": targetOrigin, "reason": reason}
              Console.error2("Preview bridge runtime closed", ctx)
              Log.error(~ctx, "Preview bridge runtime closed")
            }
          }
        )
        Client__PreviewRuntimeRegistry.register(~runtime)
        Some(
          () => {
            removeStatusListener()
            Client__PreviewRuntimeRegistry.unregister(~runtime)
            Client__PreviewRuntime.close(runtime)
          },
        )
      }
    | (false, _, _, _)
    | (_, false, _, _)
    | (_, _, None, _)
    | (_, _, _, None) =>
      None
    }
  }, (isActive, hasLoaded, attachmentKey, iframeElement, iframeSrc, taskId))

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
            : url->withPreviewBridgeParams
        }
      )
    }
    None
  }, (url, hasLoaded))

  React.useEffect(() => {
    switch isActive {
    | false => ()
    | true => setIframeSrc(prev => prev == "about:blank" ? url->withPreviewBridgeParams : prev)
    }
    None
  }, [isActive])

  React.useEffect(() => {
    switch isActive {
    | false => ()
    | true =>
      switch location {
      | Some(location) =>
        switch location->String.startsWith("http") {
        | false => ()
        | true =>
          let locationChanged = switch lastLocationRef.current {
          | None => true
          | Some(lastLocation) => lastLocation != location
          }

          switch locationChanged {
          | false => ()
          | true =>
            lastLocationRef.current = Some(location)
            Client__State.Actions.observePreviewUrl(~url=location)
          }
        }
      | None => ()
      }
    }
    None
  }, (location, isActive))

  let onLoad = (_e: JsxEvent.Image.t) => {
    switch iframeSrc {
    | "about:blank" => ()
    | _ =>
      setHasLoaded(_ => true)
      setAttachmentKey(prev => prev + 1)
      switch isActive {
      | false => ()
      | true =>
        readPreviewFrame()->Option.forEach(((contentDocument, contentWindow)) =>
          Client__State.Actions.setPreviewFrame(~contentDocument, ~contentWindow)
        )
      }
    }
  }

  React.useEffect(() => {
    switch isActive {
    | false => ()
    | true =>
      readPreviewFrame()->Option.forEach(((contentDocument, contentWindow)) => {
        switch contentDocument->Option.isSome {
        | false => ()
        | true => Client__State.Actions.setPreviewFrame(~contentDocument, ~contentWindow)
        }
      })
    }
    None
  }, [isActive])

  let refCallback = ReactDOM.Ref.callbackDomRef(iframe => {
    iframeRef.current = iframe
    let nextIframeElement =
      iframe
      ->Nullable.toOption
      ->Option.map(FrontmanBindings.Bindings__WebAPI.elementFromReact)
    setIframeElement(prevIframeElement =>
      switch (prevIframeElement, nextIframeElement) {
      | (Some(prev), Some(next)) if prev == next => prevIframeElement
      | (None, None) => prevIframeElement
      | _ => nextIframeElement
      }
    )
    None
  })
  let iframe =
    <iframe
      className="size-full" src={iframeSrc} title={`Preview - ${taskId}`} onLoad ref={refCallback}
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
