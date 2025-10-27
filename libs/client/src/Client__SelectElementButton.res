let resetDocumentCursor: unit => unit = %raw(`function() { 
  document.body.style.cursor = "default" 
}`)

external asIFrameElement: WebAPI.DOMAPI.element => WebAPI.DOMAPI.htmliFrameElement = "%identity"
external asJSON: 'a => JSON.t = "%identity"

module IFrameMessage = {
  type t = {
    @as("type") type_: [#ELEMENT_SELECTED | #SELECTION_CANCELLED],
    data?: {
      selector: string,
      reactComponent: {
        name: string,
        sourceLocation: {
          status: string,
          file: option<string>,
          line: option<int>,
        },
      },
    },
  }
}
let getIFrame = (document: WebAPI.DOMAPI.document) => {
  let iframe = document->WebAPI.Document.querySelector("#main-content-iframe")
  switch iframe->Null.toOption {
  | Some(iframe) => Some(iframe->asIFrameElement)
  | None => None
  }
}

@react.component
let make = (
  ~onElementSelected: Client__Types.SelectElement.t => unit,
  ~disabled=?,
  ~selectedElement: option<Client__Types.SelectElement.t>=?,
  ~onClearSelection: option<unit => unit>=?,
) => {
  let (isSelecting, setIsSelecting) = React.useState(_ => false)
  let (hasIframe, setHasIframe) = React.useState(_ => false)
  let (selectionSuccessful, setSelectionSuccessful) = React.useState(_ => false)
  let cleanupFunctionRef = React.useRef(Nullable.null)

  let cleanup = React.useCallback(() => {
    setIsSelecting(_ => false)
    resetDocumentCursor()
    let iframe = WebAPI.Global.document->WebAPI.Document.querySelector("#main-content-iframe")
    switch iframe->Null.toOption {
    | Some(iframe) =>
      let iframe = iframe->asIFrameElement
      switch iframe.contentWindow->Null.toOption {
      | Some(contentWindow) =>
        let message: Client__IframeUtils.iframeMessage = {
          type_: "STOP_ELEMENT_SELECTION",
        }
        contentWindow->WebAPI.Window.postMessage(~message=message->asJSON, ~targetOrigin="*")
      | None => ()
      }
    | None => ()
    }

    let overlay = WebAPI.Global.document->WebAPI.Document.querySelector("#select-element-overlay")
    switch overlay->Null.toOption {
    | Some(overlay) => overlay->WebAPI.Element.remove
    | None => ()
    }

    if cleanupFunctionRef.current->Nullable.toOption->Option.isSome {
      cleanupFunctionRef.current = Nullable.null
    }
  }, [setIsSelecting])

  let handleElementSelection = React.useCallback(
    async (event: ReactEvent.Mouse.t, targetDocument: WebAPI.DOMAPI.document) => {
      event->ReactEvent.Mouse.preventDefault
      event->ReactEvent.Mouse.stopPropagation
      let element = event->ReactEvent.Mouse.target->WebAPI.EventTarget.asElement
      switch targetDocument->WebAPI.Document.body->Null.toOption {
      | Some(body) =>
        let selector = Finder.finder(
          ~element,
          ~options={
            root: body,
            idName: (~name as _) => true,
            className: (~name as _) => true,
            tagName: (~name as _) => true,
            attr: (~name as _, ~value as _) => false,
            seedMinLength: 1,
            optimizedMinLength: 2,
            maxNumberOfPathChecks: 10000,
          },
        )

        let result = await Snapdom.snapdom(~element)
        let screenshot = result.url
        let sourceLocation = await DOMElementToComponentSource.getElementSourceLocation(~element)
        let sourceLocation = sourceLocation->Option.getOr({
          componentName: "Unknown Component",
          file: "Unknown File",
          line: 0,
        })
        let reactComponent: Client__Types.reactComponent = {
          name: sourceLocation.componentName,
          sourceLocation: Some(sourceLocation),
        }
        let selectElement = Client__Types.SelectElement.make(
          ~selector,
          ~screenshot,
          ~reactComponent,
        )
        onElementSelected(selectElement)
        setSelectionSuccessful(_ => true)
        let _timeoutId = setTimeout(() => setSelectionSuccessful(_ => false), 2000)
      | None => ()
      }
    },
    (onElementSelected, setSelectionSuccessful),
  )

  let startSelection = React.useCallback(() => {
    setIsSelecting(_ => true)
    switch WebAPI.Global.document->WebAPI.Document.body->Null.toOption {
    | Some(body) =>
      body
      ->WebAPI.Element.asHTMLElement
      ->WebAPI.HTMLElement.style
      ->WebAPI.CSSStyleDeclaration.setProperty(~property="cursor", ~value="crosshair")
    | None => ()
    }

    let getOrCreateHighlight = (document: WebAPI.DOMAPI.document) => {
      let highlightOverlay =
        document->WebAPI.Document.querySelector("#select-element-overlay")->Null.toOption
      switch highlightOverlay {
      | Some(highlightOverlay) => highlightOverlay->WebAPI.Element.asHTMLElement
      | None =>
        let overlay = document->WebAPI.Document.createElement("div")->WebAPI.Element.asHTMLElement
        overlay->WebAPI.HTMLElement.setId(~value="select-element-overlay")
        overlay
        ->WebAPI.HTMLElement.style
        ->WebAPI.CSSStyleDeclaration.setProperty(~property="position", ~value="fixed")
        overlay
        ->WebAPI.HTMLElement.style
        ->WebAPI.CSSStyleDeclaration.setProperty(~property="pointer-events", ~value="none")
        overlay
        ->WebAPI.HTMLElement.style
        ->WebAPI.CSSStyleDeclaration.setProperty(~property="border", ~value="2px solid #3b82f6")
        overlay
        ->WebAPI.HTMLElement.style
        ->WebAPI.CSSStyleDeclaration.setProperty(
          ~property="background",
          ~value="rgba(59, 130, 246, 0.1)",
        )
        overlay
        ->WebAPI.HTMLElement.style
        ->WebAPI.CSSStyleDeclaration.setProperty(~property="z-index", ~value="999999")
        overlay
        ->WebAPI.HTMLElement.style
        ->WebAPI.CSSStyleDeclaration.setProperty(
          ~property="box-shadow",
          ~value="0 0 10px rgba(59, 130, 246, 0.5)",
        )
        switch WebAPI.Global.document->WebAPI.Document.body->Null.toOption {
        | Some(body) => body->WebAPI.Element.appendChild(overlay)->ignore
        | None => ()
        }
        overlay
      }
    }

    let updateHighlight = (element: WebAPI.DOMAPI.element, document: WebAPI.DOMAPI.document) => {
      let highlightOverlay = getOrCreateHighlight(document)
      let rect = element->WebAPI.Element.getBoundingClientRect
      if document !== WebAPI.Global.document {
        let iframe =
          WebAPI.Global.document
          ->WebAPI.Document.querySelector("#main-content-iframe")
          ->Null.toOption
        switch iframe {
        | Some(iframe) =>
          let iframe = iframe->asIFrameElement
          let iframeRect =
            iframe
            ->WebAPI.HTMLIFrameElement.asHTMLElement
            ->WebAPI.HTMLElement.getBoundingClientRect
          let offsetX = iframeRect.left
          let offsetY = iframeRect.top
          highlightOverlay
          ->WebAPI.HTMLElement.style
          ->WebAPI.CSSStyleDeclaration.setProperty(
            ~property="left",
            ~value=`${(rect.left + offsetX)->Float.toString}px`,
          )
          highlightOverlay
          ->WebAPI.HTMLElement.style
          ->WebAPI.CSSStyleDeclaration.setProperty(
            ~property="top",
            ~value=`${(rect.top + offsetY)->Float.toString}px`,
          )
          highlightOverlay
          ->WebAPI.HTMLElement.style
          ->WebAPI.CSSStyleDeclaration.setProperty(
            ~property="width",
            ~value=`${rect.width->Float.toString}px`,
          )
          highlightOverlay
          ->WebAPI.HTMLElement.style
          ->WebAPI.CSSStyleDeclaration.setProperty(
            ~property="height",
            ~value=`${rect.height->Float.toString}px`,
          )
          highlightOverlay
          ->WebAPI.HTMLElement.style
          ->WebAPI.CSSStyleDeclaration.setProperty(~property="display", ~value="block")
        | None => ()
        }
      }
    }

    let removeHighlight = () => {
      let highlightOverlay = getOrCreateHighlight(WebAPI.Global.document)
      highlightOverlay->WebAPI.HTMLElement.remove
    }

    let handleMainDocumentClick = (event: ReactEvent.Mouse.t) => {
      removeHighlight()
      handleElementSelection(event, WebAPI.Global.document)->ignore
    }

    let handleMainDocumentMouseOver = (event: ReactEvent.Mouse.t) => {
      let element = event->ReactEvent.Mouse.target->WebAPI.EventTarget.asElement
      updateHighlight(element, WebAPI.Global.document)
    }

    let handleIframeClick = (event: ReactEvent.Mouse.t) => {
      let iframe = getIFrame(WebAPI.Global.document)
      let iframe =
        iframe->Option.flatMap(iframe =>
          iframe->WebAPI.HTMLIFrameElement.contentDocument->Null.toOption
        )
      switch iframe {
      | Some(iframe) =>
        removeHighlight()
        handleElementSelection(event, iframe)->ignore
      | None => ()
      }
    }

    let handleIframeMouseOver = (event: ReactEvent.Mouse.t) => {
      let iframe = getIFrame(WebAPI.Global.document)
      let iframe =
        iframe->Option.flatMap(iframe =>
          iframe->WebAPI.HTMLIFrameElement.contentDocument->Null.toOption
        )
      switch iframe {
      | Some(iframe) =>
        let element = event->ReactEvent.Mouse.target->WebAPI.EventTarget.asElement
        updateHighlight(element, iframe)->ignore
      | None => ()
      }
    }

    let handleEscapeKey = (event: ReactEvent.Keyboard.t) => {
      if event->ReactEvent.Keyboard.key === "Escape" {
        removeHighlight()
        cleanup()
      }
    }

    WebAPI.Global.document->WebAPI.Document.addEventListenerWithCapture(
      Click,
      handleMainDocumentClick,
    )
    WebAPI.Global.document->WebAPI.Document.addEventListenerWithCapture(
      Mouseover,
      handleMainDocumentMouseOver,
    )
    WebAPI.Global.document->WebAPI.Document.addEventListenerWithCapture(Keydown, handleEscapeKey)

    cleanupFunctionRef.current = Nullable.make(() => {
      removeHighlight()
      WebAPI.Global.document->WebAPI.Document.removeEventListener_useCapture(
        Click,
        handleMainDocumentClick,
      )
      WebAPI.Global.document->WebAPI.Document.removeEventListener_useCapture(
        Mouseover,
        handleMainDocumentMouseOver,
      )
      WebAPI.Global.document->WebAPI.Document.removeEventListener_useCapture(
        Keydown,
        handleEscapeKey,
      )
    })

    let iframe = getIFrame(WebAPI.Global.document)
    let iframeContentDoc =
      iframe->Option.flatMap(iframe =>
        iframe->WebAPI.HTMLIFrameElement.contentDocument->Null.toOption
      )
    switch iframeContentDoc {
    | Some(iframeContentDoc) =>
      iframeContentDoc->WebAPI.Document.addEventListenerWithCapture(Click, handleIframeClick)
      iframeContentDoc->WebAPI.Document.addEventListenerWithCapture(
        Mouseover,
        handleIframeMouseOver,
      )
      iframeContentDoc->WebAPI.Document.addEventListenerWithCapture(Keydown, handleEscapeKey)
      iframeContentDoc
      ->WebAPI.Document.body
      ->Null.toOption
      ->Option.forEach(body => {
        body
        ->WebAPI.Element.asHTMLElement
        ->WebAPI.HTMLElement.style
        ->WebAPI.CSSStyleDeclaration.setProperty(~property="cursor", ~value="crosshair")
      })
    | None => ()
    }

    let originalCleanup = cleanupFunctionRef.current->Nullable.toOption
    cleanupFunctionRef.current = Nullable.make(() => {
      originalCleanup->Option.forEach(cleanup => cleanup())
      switch iframeContentDoc {
      | Some(iframeContentDoc) =>
        iframeContentDoc->WebAPI.Document.removeEventListener_useCapture(Click, handleIframeClick)
        iframeContentDoc->WebAPI.Document.removeEventListener_useCapture(
          Mouseover,
          handleIframeMouseOver,
        )
        iframeContentDoc->WebAPI.Document.removeEventListener_useCapture(Keydown, handleEscapeKey)
        iframeContentDoc
        ->WebAPI.Document.body
        ->Null.toOption
        ->Option.forEach(
          body => {
            body
            ->WebAPI.Element.asHTMLElement
            ->WebAPI.HTMLElement.style
            ->WebAPI.CSSStyleDeclaration.setProperty(~property="cursor", ~value="default")
          },
        )
      | None => ()
      }
    })
  }, setIsSelecting)

  let handleButtonClick = React.useCallback(_event => {
    switch (disabled->Option.getOr(false), selectedElement->Option.isSome, isSelecting) {
    | (true, _, _) => ()
    | (_, true, false) =>
      switch onClearSelection {
      | Some(onClearSelection) => onClearSelection()
      | None => ()
      }
    | (_, _, true) => cleanup()
    | (_, _, false) => startSelection()
    }
  }, (disabled, isSelecting, cleanup))

  <>
    <Client__SelectionNotice
      isSelecting={isSelecting && !selectionSuccessful} isIframeMode={hasIframe} onCancel={cleanup}
    />
    {switch selectionSuccessful {
    | true => <Client__SelectionNotice isSelecting={false} isIframeMode={false} />
    | false => React.null
    }}
    <button
      onClick={handleButtonClick}
      disabled={disabled->Option.getOr(false)}
      title={selectedElement->Option.isSome
        ? "Clear Selection"
        : isSelecting
        ? "Cancel Selection"
        : "Select Element"}
      style={
        width: "28px",
        height: "28px",
        backgroundColor: isSelecting
          ? "#ef4444"
          : selectedElement->Option.isSome
          ? "#10b981"
          : "#6b7280",
        border: "none",
        borderRadius: "4px",
        cursor: disabled->Option.getOr(false) ? "not-allowed" : "pointer",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        transition: "background-color 0.2s",
      }
    />
    <RadixUI__Icons.TargetIcon width="14" height="14" color="white" />
  </>
}
