// Helper to create the iframe ref callback (avoids duplication across branches)
let makeRefCallback = (iframeRef: React.ref<Nullable.t<Dom.element>>) => {
  ReactDOM.Ref.callbackDomRef(iframe => {
    iframeRef.current = iframe
    Some(
      () => {
        iframeRef.current = Nullable.null
      },
    )
  })
}

@react.component
let make = (~taskId, ~url, ~isActive, ~viewportStyle: option<(int, int, float)>=?) => {
  let iframeRef: React.ref<Nullable.t<Dom.element>> = React.useRef(Nullable.null)
  let lastLocationRef: React.ref<option<string>> = React.useRef(None)
  let location = Client__Hooks.useIFrameLocation(~iframeRef=iframeRef.current->Obj.magic)
  React.useEffect(() => {
    if isActive {
      switch location {
      | Some(location) =>
        if location->String.startsWith("http") {
          // Only update if location actually changed
          let locationChanged = switch lastLocationRef.current {
          | None => true
          | Some(lastLocation) => lastLocation != location
          }

          if locationChanged {
            lastLocationRef.current = Some(location)
            Client__State.Actions.setPreviewUrl(~url=location)
          }
        }
      | None => ()
      }
    }
    None
  }, (location, isActive))

  let onLoad = (_e: JsxEvent.Image.t) => {
    if isActive {
      iframeRef.current
      ->Nullable.toOption
      ->Option.forEach(iframe => {
        let iframeElement = iframe->Obj.magic
        try {
          let contentDocument = WebAPI.HTMLIFrameElement.contentDocument(iframeElement)->Null.toOption
          let contentWindow = WebAPI.HTMLIFrameElement.contentWindow(iframeElement)->Null.toOption
          Client__State.Actions.setPreviewFrame(~contentDocument, ~contentWindow)
        } catch {
        // Cross-origin iframes throw SecurityError when accessing contentDocument/contentWindow
        | _ => ()
        }
      })
    }
  }

  // Update preview frame when this iframe becomes active and is already loaded
  React.useEffect(() => {
    if isActive {
      iframeRef.current
      ->Nullable.toOption
      ->Option.forEach(iframe => {
        let iframeElement = iframe->Obj.magic
        try {
          let contentDocument = WebAPI.HTMLIFrameElement.contentDocument(iframeElement)->Null.toOption
          let contentWindow = WebAPI.HTMLIFrameElement.contentWindow(iframeElement)->Null.toOption

          // Only update if the iframe has content loaded
          if contentDocument->Option.isSome {
            Client__State.Actions.setPreviewFrame(~contentDocument, ~contentWindow)
          }
        } catch {
        // Cross-origin iframes throw SecurityError when accessing contentDocument/contentWindow
        | _ => ()
        }
      })
    }
    None
  }, [isActive])

  let refCallback = makeRefCallback(iframeRef)

  // Render based on active state and device mode
  switch (isActive, viewportStyle) {
  | (false, _) =>
    // Inactive: position offscreen to preserve iframe state
    <div className="absolute -left-[9999px] -top-[9999px] invisible size-full">
      <iframe className="size-full" src={url} title={`Preview - ${taskId}`} onLoad ref={refCallback} />
    </div>
  | (true, None) =>
    // Active + Responsive mode: fill available space
    <div className="flex-1 size-full">
      <iframe className="size-full" src={url} title={`Preview - ${taskId}`} onLoad ref={refCallback} />
    </div>
  | (true, Some((deviceWidth, deviceHeight, scale))) =>
    // Active + Device mode: constrained viewport with optional scaling
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
      <iframe className="size-full" src={url} title={`Preview - ${taskId}`} onLoad ref={refCallback} />
    </div>
  }
}
