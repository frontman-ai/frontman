/**
 * Client__WebPreview - Web preview panel with navigation
 * 
 * Uses pure ReScript navigation components instead of AIElements.
 */

module Nav = Client__WebPreview__Nav
module RadixUI__Icons = Bindings__RadixUI__Icons
module FigmaNode = Client__State__Types.FigmaNode
module AlertDialog = Bindings__UI__AlertDialog.AlertDialog
module AlertDialogContent = Bindings__UI__AlertDialog.AlertDialogContent
module AlertDialogHeader = Bindings__UI__AlertDialog.AlertDialogHeader
module AlertDialogTitle = Bindings__UI__AlertDialog.AlertDialogTitle
module AlertDialogDescription = Bindings__UI__AlertDialog.AlertDialogDescription
module AlertDialogFooter = Bindings__UI__AlertDialog.AlertDialogFooter
module AlertDialogAction = Bindings__UI__AlertDialog.AlertDialogAction

module BackButton = {
  @react.component
  let make = (~onClick: unit => unit) => {
    <Nav.NavButton onClick={onClick} tooltip="Go back">
      <RadixUI__Icons.ArrowLeftIcon className="size-4" />
    </Nav.NavButton>
  }
}

module ForwardButton = {
  @react.component
  let make = (~onClick: unit => unit) => {
    <Nav.NavButton onClick={onClick} tooltip="Go forward">
      <RadixUI__Icons.ArrowRightIcon className="size-4" />
    </Nav.NavButton>
  }
}

module ReloadButton = {
  @react.component
  let make = (~onClick: unit => unit) => {
    <Nav.NavButton onClick={onClick} tooltip="Reload">
      <RadixUI__Icons.ReloadIcon className="size-4" />
    </Nav.NavButton>
  }
}

module SelectFigmaNode = {
  @react.component
  let make = (~onClick: unit => unit, ~figmaNode: FigmaNode.t) => {
    <div
      className={switch figmaNode {
      | FigmaNode.WaitingForSelection => "rounded bg-purple-500/20"
      | _ => ""
      }}
    >
      <Nav.NavButton onClick={onClick} tooltip="Import from Figma">
        <RadixUI__Icons.FigmaIcon
          className={switch figmaNode {
          | FigmaNode.WaitingForSelection => "size-4 text-purple-500"
          | _ => "size-4"
          }}
          style={{"width": "16px", "height": "16px"}}
        />
      </Nav.NavButton>
    </div>
  }
}

module SelectElement = {
  @react.component
  let make = (~onClick: unit => unit, ~isSelecting: bool) => {
    <div
      className={isSelecting
        ? "rounded-md bg-blue-500 shadow-sm shadow-blue-500/30"
        : "rounded-md hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"}
    >
      <Nav.NavButton
        onClick={onClick}
        tooltip={isSelecting ? "Exit selection mode" : "Select element"}
      >
        <RadixUI__Icons.Crosshair1Icon
          className={isSelecting
            ? "size-4 text-white"
            : "size-4 text-gray-600 dark:text-gray-400"}
        />
      </Nav.NavButton>
    </div>
  }
}

module OpenInNewWindow = {
  @react.component
  let make = (~onClick: unit => unit) => {
    <Nav.NavButton onClick={onClick} tooltip="Open in new tab">
      <RadixUI__Icons.OpenInNewWindowIcon className="size-4" />
    </Nav.NavButton>
  }
}

@react.component
let make = () => {
  let (showExtensionAlert, setShowExtensionAlert) = React.useState(() => false)
  let currentTaskId = Client__State.useSelector(Client__State.Selectors.currentTaskId)
  let allTasks = Client__State.useSelector(Client__State.Selectors.tasks)
  let previewUrl = Client__State.useSelector(Client__State.Selectors.previewUrl)
  let previewFrame = Client__State.useSelector(Client__State.Selectors.previewFrame)
  let isNewTask = Client__State.useSelector(Client__State.Selectors.isNewTask)
  let webPreviewIsSelecting = Client__State.useSelector(
    Client__State.Selectors.webPreviewIsSelecting,
  )
  let figmaNode = Client__State.useSelector(Client__State.Selectors.figmaNode)
  let isExtensionInstalled = Client__ExtensionState.useSelector(
    Client__ExtensionState.Selectors.isInstalled,
  )

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
  let handleFigma = () => {
    if !isExtensionInstalled {
      setShowExtensionAlert(_ => true)
    } else {
      Client__State.Actions.setFigmaNodeWaiting()
      FrontmanBindings.Chrome.Runtime.sendMessageExternal(
        "kfdpjbmabcelpgoipaccjijhehdmeghp",
        {"type": "DevServerImportFigmaNodeRequest"},
        response => {
          Console.log2("DevServerImportFigmaNodeRequest response:", response)
        },
      )
    }
  }
  let handleOpenInNewTab = () => {
    WebAPI.Window.open_(
      WebAPI.Global.window,
      ~url=previewUrl,
      ~target="_blank",
      ~features="noopener,noreferrer",
    )->ignore
  }
  
  <>
    <Nav.Container>
      <Nav.Navigation>
        <BackButton onClick={handleBack} />
        <ForwardButton onClick={handleForward} />
        <ReloadButton onClick={handleReload} />
        <Nav.UrlInput value={previewUrl} />
        <SelectFigmaNode onClick={handleFigma} figmaNode={figmaNode} />
        <SelectElement onClick={handleSelect} isSelecting={webPreviewIsSelecting} />
        <OpenInNewWindow onClick={handleOpenInNewTab} />
      </Nav.Navigation>

      <div className="relative size-full overflow-y-hidden">
        {switch previewFrame.contentDocument {
        | Some(document) => <Client__WebPreview__Stage document={document} />
        | _ => React.null
        }}

        {isNewTask
          ? <Client__WebPreview__Body key="__new__" taskId="__new__" url={previewFrame.url} isActive={true} />
          : React.null}
        {allTasks
          ->Array.map(task => {
            let taskId = Client__Task__Types.Task.getId(task)->Option.getOrThrow
            let taskPreviewFrame = Client__Task__Types.Task.getPreviewFrame(task, ~defaultUrl=Client__State__StateReducer.getInitialUrl())
            <Client__WebPreview__Body
              key={taskId} taskId={taskId} url={taskPreviewFrame.url} isActive={currentTaskId == Some(taskId)}
            />
          })
          ->React.array}
      </div>
    </Nav.Container>

    <AlertDialog
      open_={showExtensionAlert} onOpenChange={isOpen => setShowExtensionAlert(_ => isOpen)}
    >
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle> {React.string("Frontman Extension Required")} </AlertDialogTitle>
          <AlertDialogDescription>
            {React.string(`To use the Figma selection feature, you need to install the Frontman browser extension. The extension allows you to import designs directly from Figma into your project.`)}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogAction
            onClick={_ => {
              WebAPI.Window.open_(
                WebAPI.Global.window,
                ~url="https://chrome.google.com/webstore",
                ~target="_blank",
                ~features="noopener,noreferrer",
              )->ignore
              setShowExtensionAlert(_ => false)
            }}
          >
            {React.string("Install Extension")}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  </>
}
