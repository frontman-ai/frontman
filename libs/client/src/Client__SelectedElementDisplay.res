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
  | Some({sourceLocation, _}) => {
      let hasParent = sourceLocation->Option.mapOr(false, loc => loc.parent->Option.isSome)
      let hasHistory = Array.length(history) > 0

      <div
        className="px-4 py-2 bg-blue-50 dark:bg-blue-950/20 border-b border-blue-200 dark:border-blue-800 text-sm overflow-hidden text-ellipsis text-nowrap text-ellipsis"
      >
        <div className="flex items-start gap-2">
          <Icons.CubeIcon
            className="size-4 text-blue-600 dark:text-blue-400 mt-0.5 flex-shrink-0"
          />
          <div className="flex-grow min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="font-semibold text-blue-900 dark:text-blue-100">
                {React.string("React Component:")}
              </span>
              {sourceLocation->Option.mapOr(React.null, loc => {
                let compName = loc.componentName->Option.getOr(loc.tagName)
                <span
                  className="font-medium font-mono text-xs text-yellow-700 dark:text-yellow-300"
                >
                  {React.string(
                    `<${compName}><${loc.tagName->String.toLowerCase} /></${compName}>`,
                  )}
                </span>
              })}
            </div>
          </div>

          <div className="flex items-center gap-1 flex-shrink-0">
            <button
              onClick={_ => navigateUp()}
              disabled={!hasParent}
              className={hasParent
                ? "text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-200"
                : "text-gray-400 dark:text-gray-600 cursor-not-allowed"}
              title={hasParent ? "Go to parent component" : "No parent component"}
            >
              <Icons.ChevronUpIcon className="size-4" />
            </button>

            <button
              onClick={_ => navigateDown()}
              disabled={!hasHistory}
              className={hasHistory
                ? "text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-200"
                : "text-gray-400 dark:text-gray-600 cursor-not-allowed"}
              title={hasHistory ? "Go back to child component" : "No navigation history"}
            >
              <Icons.ChevronDownIcon className="size-4" />
            </button>
          </div>

          <button
            onClick={_ => Client__State.Actions.setSelectedElement(~selectedElement=None)}
            className="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-200 flex-shrink-0"
            title="Clear selection"
          >
            <Icons.Cross2Icon className="size-4" />
          </button>
        </div>
      </div>
    }
  }
}
