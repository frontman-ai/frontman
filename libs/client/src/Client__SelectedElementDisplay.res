module Icons = Client__ToolIcons
module RadixIcons = Bindings__RadixUI__Icons

@react.component
let make = () => {
  let selectedElement = Client__State.useSelector(Client__State.Selectors.selectedElement)

  // History to track previous selected elements when going up
  let (history, setHistory) = React.useState(() => [])

  // Track if we're in the middle of a navigation operation
  let isNavigating = React.useRef(false)

  // Navigate to parent component
  let navigateUp = () => {
    switch selectedElement {
    | Some({sourceLocation: Some(currentLoc), element, selector, screenshot}) =>
      switch currentLoc.parent {
      | Some(parentLoc) => {
          // Get parent DOM element
          let parentElement =
            element->WebAPI.Element.asNode->WebAPI.Node.parentElement->Null.toOption

          switch parentElement {
          | Some(parentEl) => {
              // Save current COMPLETE state (element, selector, screenshot, sourceLocation) to history
              let currentState: Client__State__StateReducer.SelectedElement.t = {
                element,
                selector,
                screenshot,
                sourceLocation: Some(currentLoc),
              }
              setHistory(prevHistory => Array.concat(prevHistory, [currentState]))

              // Enrich parent location with tagName from parent element
              let parentLocWithTagName = {...parentLoc, tagName: parentEl.tagName}

              // Update selected element with parent location and parent element
              // Trigger re-fetch of selector and screenshot for the parent element
              let newSelectedElement: option<Client__State__StateReducer.SelectedElement.t> = Some({
                element: parentEl,
                selector: None, // Will be fetched
                screenshot: None, // Will be fetched
                sourceLocation: Some(parentLocWithTagName),
              })

              // Set flag to prevent history clearing
              isNavigating.current = true
              Client__State.Actions.setSelectedElement(~selectedElement=newSelectedElement)
            }
          | None => ()
          }
        }
      | None => ()
      }
    | Some({sourceLocation: None, _}) => ()
    | None => ()
    }
  }

  // Navigate back down to previous component
  let navigateDown = () => {
    let historyLength = Array.length(history)

    if historyLength > 0 {
      switch selectedElement {
      | Some(_) =>
        // Get last item from history (complete state)
        switch history->Array.get(historyLength - 1) {
        | Some(previousState) => {
            // Remove last item from history
            setHistory(prevHistory => Array.slice(prevHistory, ~start=0, ~end=historyLength - 1))

            // Restore the complete previous state
            let newSelectedElement: option<Client__State__StateReducer.SelectedElement.t> = Some(
              previousState,
            )

            // Set flag to prevent history clearing
            isNavigating.current = true
            Client__State.Actions.setSelectedElement(~selectedElement=newSelectedElement)
          }
        | None => ()
        }
      | None => ()
      }
    }
  }

  switch selectedElement {
  | None => React.null
  | Some({sourceLocation, element, _}) => {
      let hasParent = sourceLocation->Option.mapOr(false, loc => loc.parent->Option.isSome)
      let hasHistory = Array.length(history) > 0

      let tagName = element.tagName->String.toLowerCase
      let textContent =
        element
        ->WebAPI.Element.asNode
        ->WebAPI.Node.textContent
        ->Null.toOption
        ->Option.getOr("")
        ->String.trim

      <div
        className="mx-3 mb-2 rounded-xl border border-[#8051CD]/40 bg-[#180C2D]/80 overflow-hidden"
      >
        // Header row: icon + "Selected Element" + nav buttons + clear
        <div className="flex items-center gap-2.5 px-3.5 py-2.5">
          <Icons.CursorClickIcon size=18 className="text-[#985DF7] flex-shrink-0" />
          <span className="font-mono text-sm font-semibold text-[#985DF7] flex-grow">
            {React.string("Selected Element")}
          </span>
          // Navigation: down, up
          <div className="flex items-center gap-0.5 flex-shrink-0">
            <button
              onClick={_ => navigateDown()}
              disabled={!hasHistory}
              className={`p-1 rounded transition-colors ${hasHistory
                ? "text-zinc-300 hover:bg-[#8051CD]/30"
                : "text-zinc-600 cursor-not-allowed"}`}
              title={hasHistory ? "Go back to child" : "No navigation history"}
            >
              <RadixIcons.ChevronDownIcon className="size-4" />
            </button>
            <button
              onClick={_ => navigateUp()}
              disabled={!hasParent}
              className={`p-1 rounded transition-colors ${hasParent
                ? "text-zinc-300 hover:bg-[#8051CD]/30"
                : "text-zinc-600 cursor-not-allowed"}`}
              title={hasParent ? "Select parent component" : "No parent component"}
            >
              <RadixIcons.ChevronUpIcon className="size-4" />
            </button>
          </div>
          // Clear button
          <button
            onClick={_ => Client__State.Actions.setSelectedElement(~selectedElement=None)}
            className="px-2.5 py-1 rounded-md text-xs font-medium text-zinc-300 bg-[#8051CD]/25 hover:bg-[#8051CD]/40 transition-colors flex-shrink-0"
            title="Clear selection"
          >
            {React.string("Clear")}
          </button>
        </div>
        // Content rows
        <div className="px-3.5 pb-3 flex flex-col gap-1 min-w-0">
          // Component name row (only when source location exists)
          {sourceLocation->Option.mapOr(React.null, loc =>
            loc.componentName->Option.mapOr(React.null, compName =>
              <div className="font-mono text-sm text-zinc-200 truncate">
                {React.string(`<${compName} />`)}
              </div>
            )
          )}
          // Element info row: <tag>: text content (CSS ellipsis)
          <div className="font-mono text-sm text-zinc-300 truncate">
            {React.string(
              if textContent->String.length > 0 {
                `<${tagName}>: ${textContent}`
              } else {
                `<${tagName}>`
              },
            )}
          </div>
        </div>
      </div>
    }
  }
}
