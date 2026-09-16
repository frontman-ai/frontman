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
      try {
        iframeElement.contentWindow
        ->Null.map(window => {
          let document = window->WebAPI.Window.document
          (Some(document), Some(window))
        })
        ->Null.getOr((None, None))
      } catch {
      | exn if exn->JsExn.fromException->Option.flatMap(JsExn.name) == Some("SecurityError") => (
          None,
          None,
        )
      | exn => throw(exn)
      }
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
        let removeStatusListener = Client__PreviewRuntime.onStatus(runtime, status =>
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
        )
        Client__PreviewRuntimeRegistry.register(~clientId=taskId, ~runtime)
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
