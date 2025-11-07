module AIElements = Bindings__AIElements
module RadixUI__Icons = Bindings__RadixUI__Icons

@react.component
let make = (~url) => {
  let currentTaskId = Client__State.useSelector(Client__State.Selectors.currentTaskId)
  let allTasks = Client__State.useSelector(Client__State.Selectors.tasks)
  let previewUrl = Client__State.useSelector(Client__State.Selectors.previewUrl)
  let previewFrame = Client__State.useSelector(Client__State.Selectors.previewFrame)
  let webPreviewIsSelecting = Client__State.useSelector(Client__State.Selectors.webPreviewIsSelecting)


  let handleBack = () => {
    previewFrame.contentWindow->Option.forEach(contentWindow => {
      WebAPI.History.back(contentWindow.history)
    })
    Client__State.Actions.setSelectedElement(~selectedElement=None)
  }
  
  let handleForward = () => {
    previewFrame.contentWindow->Option.forEach(contentWindow => {
      WebAPI.History.forward(contentWindow.history)
    })
    Client__State.Actions.setSelectedElement(~selectedElement=None)
  }
  
  let handleReload = () => {
    previewFrame.contentWindow->Option.forEach(contentWindow => {
      WebAPI.Location.reload(contentWindow.location)
    })
    Client__State.Actions.setSelectedElement(~selectedElement=None)
  }
  let handleSelect = () => Client__State.Actions.toggleWebPreviewSelection()
  let handleOpenInNewTab = () => {
    WebAPI.Window.open_(WebAPI.Global.window, ~url=url, ~target="_blank", ~features="noopener,noreferrer")->ignore
  }
  <AIElements.WebPreview defaultUrl={url}>
    <AIElements.WebPreviewNavigation>
      <AIElements.WebPreviewNavigationButton onClick={handleBack} tooltip="Go back">
        <RadixUI__Icons.ArrowLeftIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
      <AIElements.WebPreviewNavigationButton onClick={handleForward} tooltip="Go forward">
        <RadixUI__Icons.ArrowRightIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
      <AIElements.WebPreviewNavigationButton onClick={handleReload} tooltip="Reload">
        <RadixUI__Icons.ReloadIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
      <AIElements.WebPreviewUrl value={previewUrl} />
      <div className={webPreviewIsSelecting ? "rounded bg-blue-500/20" : ""}>
        <AIElements.WebPreviewNavigationButton 
          onClick={handleSelect} 
          tooltip="Select"
        >
          <RadixUI__Icons.Crosshair1Icon className={webPreviewIsSelecting ? "size-4 text-blue-500" : "size-4"} />
        </AIElements.WebPreviewNavigationButton>
      </div>
      <AIElements.WebPreviewNavigationButton onClick={handleOpenInNewTab} tooltip="Open in new tab">
        <RadixUI__Icons.OpenInNewWindowIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
    </AIElements.WebPreviewNavigation>
    
    <div className="relative size-full">
      {switch (previewFrame.contentDocument, previewFrame.contentWindow) {
      | (Some(document), Some(window)) => <Client__WebPreview__Stage document={document} window={window} />
      | (_, _) => React.null
      }}

      {allTasks
      ->Array.map(task => {
        let isActive = currentTaskId->Option.mapOr(false, id => id == task.id)
        <Client__WebPreview__Body
          key={task.id}
          taskId={task.id}
          url={task.previewFrame.url}
          isActive={isActive}
        />
      })
      ->React.array}
    </div>
  </AIElements.WebPreview>
}
