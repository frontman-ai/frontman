module Icons = Bindings__RadixUI__Icons

@react.component
let make = () => {
  let selectedElement = Client__State.useSelector(Client__State.Selectors.selectedElement)

  // History to track previous selected elements when going up
  let (history, setHistory) = React.useState(() => [])

  // Track if we're in the middle of a navigation operation
  let isNavigating = React.useRef(false)

  // Clear history when selection changes from OUTSIDE (not from our navigation)
  // React.useEffect1(() => {
  //   if !isNavigating.current {
  //     setHistory(_ => [])
  //   } else {
  //     // Reset the flag
  //     isNavigating.current = false
  //   }
  //   None
  // }, [selectedElement])

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
      
      // Get element info for display using shared utils
      let tagName = element.tagName->String.toLowerCase
      let elementId = Client__WebPreview__Utils.getElementId(element.id)
      let elementClass = Client__WebPreview__Utils.getFirstClassName(element.className)

      <div
        className="px-3 py-2.5 bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-950/30 dark:to-indigo-950/30 border-b border-blue-200/80 dark:border-blue-800/50"
      >
        <div className="flex items-center gap-3">
          // Component icon
          <div className="flex-shrink-0 p-1.5 bg-blue-500 rounded-md shadow-sm">
            <Icons.CubeIcon className="size-4 text-white" />
          </div>
          // Component info
          <div className="flex-grow min-w-0 flex items-center gap-2">
            {sourceLocation->Option.mapOr(
              // No source location - just show element
              <span className="font-mono text-sm text-gray-700 dark:text-gray-300">
                {React.string(`<${tagName}>`)}
              </span>,
              loc => {
                let compName = loc.componentName->Option.getOr(tagName)
                // Component name and badges
                <>
                  <span className="font-semibold text-sm text-blue-900 dark:text-blue-100">
                    {React.string(compName)}
                  </span>
                  <span
                    className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-mono bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400"
                  >
                    {React.string(`<${tagName}>`)}
                  </span>
                  {elementId->Option.mapOr(React.null, id =>
                    <span
                      className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-mono bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400"
                    >
                      {React.string(`#${id}`)}
                    </span>
                  )}
                  {elementClass->Option.mapOr(React.null, cn =>
                    <span
                      className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-mono bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400"
                    >
                      {React.string(`.${cn}`)}
                    </span>
                  )}
                </>
              },
            )}
          </div>
          // Navigation controls
          <div className="flex items-center gap-0.5 flex-shrink-0">
            <button
              onClick={_ => navigateUp()}
              disabled={!hasParent}
              className={`p-1 rounded transition-colors ${hasParent
                ? "text-blue-600 dark:text-blue-400 hover:bg-blue-100 dark:hover:bg-blue-900/50"
                : "text-gray-300 dark:text-gray-600 cursor-not-allowed"}`}
              title={hasParent ? "Select parent component" : "No parent component"}
            >
              <Icons.ChevronUpIcon className="size-4" />
            </button>

            <button
              onClick={_ => navigateDown()}
              disabled={!hasHistory}
              className={`p-1 rounded transition-colors ${hasHistory
                ? "text-blue-600 dark:text-blue-400 hover:bg-blue-100 dark:hover:bg-blue-900/50"
                : "text-gray-300 dark:text-gray-600 cursor-not-allowed"}`}
              title={hasHistory ? "Go back to child" : "No navigation history"}
            >
              <Icons.ChevronDownIcon className="size-4" />
            </button>
            
            <div className="w-px h-4 bg-gray-200 dark:bg-gray-700 mx-1" />

            <button
              onClick={_ => Client__State.Actions.setSelectedElement(~selectedElement=None)}
              className="p-1 rounded text-gray-500 dark:text-gray-400 hover:text-red-500 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/30 transition-colors"
              title="Clear selection"
            >
              <Icons.Cross2Icon className="size-4" />
            </button>
          </div>
        </div>
      </div>
    }
  }
}
