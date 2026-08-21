@react.component
let make = (~clientId, ~url, ~isActive, ~viewportStyle: option<(int, int, float)>=?) => {
  let iframeRef: React.ref<Nullable.t<Dom.element>> = React.useRef(Nullable.null)
  let (iframeElement, setIframeElement): (option<WebAPI.DomTypes.element>, _) = React.useState(() =>
    None
  )
  let (attachmentKey, setAttachmentKey) = React.useState(() => 0)
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
      (
        WebAPI.HTMLIFrameElement.contentDocument(iframeElement),
        WebAPI.HTMLIFrameElement.contentWindow(iframeElement),
      )
    })

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
            Client__State.Actions.setPreviewUrl(~clientId, ~url=location)
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
          Client__State.Actions.setPreviewFrame(~clientId, ~contentDocument, ~contentWindow)
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
        | true => Client__State.Actions.setPreviewFrame(~clientId, ~contentDocument, ~contentWindow)
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
      className="size-full" src={iframeSrc} title={`Preview - ${clientId}`} onLoad ref={refCallback}
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
