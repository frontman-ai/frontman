@react.component
let make = (~taskId, ~url, ~isActive) => {
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

  <div
    className={isActive
      ? "flex-1 size-full"
      : "absolute -left-[9999px] -top-[9999px] invisible size-full"}
  >
    <iframe
      className={"size-full"}
      src={url}
      title={`Preview - ${taskId}`}
      onLoad={onLoad}
      ref={ReactDOM.Ref.callbackDomRef(iframe => {
        iframeRef.current = iframe
        Some(
          () => {
            iframeRef.current = Nullable.null
          },
        )
      })}
    />
  </div>
}
