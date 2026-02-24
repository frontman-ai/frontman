@react.component
let make = (~taskId, ~url, ~isActive, ~viewportStyle: option<(int, int, float)>=?) => {
  let iframeRef: React.ref<Nullable.t<Dom.element>> = React.useRef(Nullable.null)
  let (iframeElement, setIframeElement): (option<WebAPI.DOMAPI.element>, _) = React.useState(() => None)
  let (attachmentKey, setAttachmentKey) = React.useState(() => 0)
  let (iframeSrc, setIframeSrc) = React.useState(() => url)
  let (hasLoaded, setHasLoaded) = React.useState(() => false)
  let lastLocationRef: React.ref<option<string>> = React.useRef(None)
  let trackedIframeElement = isActive ? iframeElement : None
  let location = Client__Hooks.useIFrameLocation(~iframeElement=trackedIframeElement, ~attachmentKey)

  React.useEffect(() => {
    switch hasLoaded {
    | false => setIframeSrc(prev => prev == url ? prev : url)
    | true => ()
    }
    None
  }, (url, hasLoaded))

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
            Client__State.Actions.setPreviewUrl(~url=location)
            Client__BrowserUrl.syncBrowserUrl(~previewUrl=location)
          }
        }
      | None => ()
      }
    }
    None
  }, (location, isActive))

  let onLoad = (_e: JsxEvent.Image.t) => {
    setHasLoaded(_ => true)
    setAttachmentKey(prev => prev + 1)
    switch isActive {
    | false => ()
    | true =>
      iframeRef.current
      ->Nullable.toOption
      ->Option.forEach(iframe => {
        let iframeElement = iframe->Obj.magic
        try {
          let contentDocument = WebAPI.HTMLIFrameElement.contentDocument(iframeElement)->Null.toOption
          let contentWindow = WebAPI.HTMLIFrameElement.contentWindow(iframeElement)->Null.toOption
          Client__State.Actions.setPreviewFrame(~contentDocument, ~contentWindow)
        } catch {
        | _ => ()
        }
      })
    }
  }

  React.useEffect(() => {
    switch isActive {
    | false => ()
    | true =>
      iframeRef.current
      ->Nullable.toOption
      ->Option.forEach(iframe => {
        let iframeElement = iframe->Obj.magic
        try {
          let contentDocument = WebAPI.HTMLIFrameElement.contentDocument(iframeElement)->Null.toOption
          let contentWindow = WebAPI.HTMLIFrameElement.contentWindow(iframeElement)->Null.toOption

          switch contentDocument->Option.isSome {
          | false => ()
          | true => Client__State.Actions.setPreviewFrame(~contentDocument, ~contentWindow)
          }
        } catch {
        | _ => ()
        }
      })
    }
    None
  }, [isActive])

  let refCallback = ReactDOM.Ref.callbackDomRef(iframe => {
    iframeRef.current = iframe
    let nextIframeElement = iframe->Nullable.toOption->Option.map(el => el->Obj.magic)
    setIframeElement(prevIframeElement =>
      switch (prevIframeElement, nextIframeElement) {
      | (Some(prev), Some(next)) if prev == next => prevIframeElement
      | (None, None) => prevIframeElement
      | _ => nextIframeElement
      }
    )
    None
  })

  switch (isActive, viewportStyle) {
  | (false, _) =>
    <div className="absolute -left-[9999px] -top-[9999px] invisible size-full">
      <iframe className="size-full" src={iframeSrc} title={`Preview - ${taskId}`} onLoad ref={refCallback} />
    </div>
  | (true, None) =>
    <div className="flex-1 size-full">
      <iframe className="size-full" src={iframeSrc} title={`Preview - ${taskId}`} onLoad ref={refCallback} />
    </div>
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
      <iframe className="size-full" src={iframeSrc} title={`Preview - ${taskId}`} onLoad ref={refCallback} />
    </div>
  }
}
