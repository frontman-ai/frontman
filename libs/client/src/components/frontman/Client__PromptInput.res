/**
 * Client__PromptInput - Main chat input component
 *
 * Prompt composer shell. Tiptap owns editor content, pills, paste/drop, and file picker.
 * This component keeps app-level controls around it: model selector, selected-element
 * button, submit/stop button, provider CTA, error toast, and image preview.
 */
module Icons = Client__ToolIcons
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

type inputItem = FileAttachment({id: string, name: string, mediaType: string, dataUrl: string})

let isComposerBeamActive = (~hasFocus, ~isInputDisabled) => !hasFocus && !isInputDisabled

module ModelSelector = {
  module Select = Client__UI__Select
  module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

  let optionClassName = "text-xs text-zinc-200 focus:bg-zinc-700 focus:text-white data-highlighted:bg-zinc-700 data-highlighted:text-white"

  let _getSelectedDisplay = (configOption: ACP.sessionConfigOption, selectedValue: string): option<
    string,
  > => {
    switch configOption {
    | ACP.SelectConfigOption({options}) =>
      switch options {
      | ACP.Grouped(groups) =>
        groups->Array.findMap(group =>
          group.options->Array.findMap(opt =>
            switch opt.value == selectedValue {
            | true => Some(opt.name)
            | false => None
            }
          )
        )
      | ACP.Ungrouped(opts) =>
        opts->Array.findMap(opt =>
          switch opt.value == selectedValue {
          | true => Some(opt.name)
          | false => None
          }
        )
      }
    }
  }

  @react.component
  let make = (
    ~configOption: ACP.sessionConfigOption,
    ~selectedValue: string,
    ~onModelChange: string => unit,
  ) => {
    let selectedDisplay = React.useMemo2(
      () => _getSelectedDisplay(configOption, selectedValue),
      (configOption, selectedValue),
    )

    <Select value={selectedValue} onValueChange={(value, _) => onModelChange(value)}>
      <Select.Trigger
        id="frontman-model-selector"
        ariaLabel="Model"
        className="inline-flex w-full min-w-0 items-center gap-1 h-9 pl-2 pr-1.5 text-xs rounded-md
                   bg-transparent text-zinc-400 border-none cursor-pointer
                   hover:text-zinc-200 hover:bg-white/6
                   focus:outline-none focus:ring-0
                   data-[placeholder]:text-zinc-500 [&_svg]:size-3 [&_svg]:text-zinc-400"
      >
        <span className="shrink-0 text-zinc-500"> {React.string("Model")} </span>
        <span className="shrink-0 text-zinc-600"> {React.string("\u{B7}")} </span>
        <span className="min-w-0 truncate text-zinc-300">
          {React.string(selectedDisplay->Option.getOr("Select model..."))}
        </span>
      </Select.Trigger>
      <Select.Content
        sideOffset=4.
        className="z-50 min-w-[180px] max-h-[300px] overflow-hidden
                   bg-zinc-800 border border-zinc-700 rounded-lg shadow-xl
                   animate-in fade-in-0 zoom-in-95"
      >
        {switch configOption {
        | ACP.SelectConfigOption({options}) =>
          switch options {
          | ACP.Grouped(groups) =>
            groups
            ->Array.map(group => {
              <Select.Group key={group.group}>
                <Select.Label className="px-2 py-1.5 text-xs font-medium text-zinc-400">
                  {React.string(group.name)}
                </Select.Label>
                {group.options
                ->Array.map(opt => {
                  <Select.Item key={opt.value} value={opt.value} className=optionClassName>
                    {React.string(opt.name)}
                  </Select.Item>
                })
                ->React.array}
              </Select.Group>
            })
            ->React.array
          | ACP.Ungrouped(opts) =>
            <Select.Group>
              {opts
              ->Array.map(opt => {
                <Select.Item key={opt.value} value={opt.value} className=optionClassName>
                  {React.string(opt.name)}
                </Select.Item>
              })
              ->React.array}
            </Select.Group>
          }
        }}
      </Select.Content>
    </Select>
  }
}

module AgentSelector = {
  module Select = Client__UI__Select

  @react.component
  let make = (
    ~agents: array<ACP.agentCatalogEntry>,
    ~selectedAgentId: string,
    ~onAgentChange: string => unit,
  ) => {
    let selectedAgent = Client__Agent.findOrThrow(Some(agents), selectedAgentId)

    <Select value={selectedAgentId} onValueChange={(value, _) => onAgentChange(value)}>
      <Select.Trigger
        id="frontman-agent-selector"
        ariaLabel="Agent"
        className="h-9 w-full min-w-0 border-none bg-transparent px-1.5 text-xs text-zinc-300
                   hover:bg-white/6 focus:ring-0 cursor-pointer [&_svg]:size-3"
      >
        <span className="shrink-0 text-zinc-500"> {React.string("Agent")} </span>
        <span className="shrink-0 text-zinc-600"> {React.string("\u{B7}")} </span>
        <span
          className="size-1.5 shrink-0 rounded-full opacity-70"
          style={{backgroundColor: selectedAgent.color}}
        />
        <span className="min-w-0 truncate"> {React.string(selectedAgent.displayName)} </span>
      </Select.Trigger>
      <Select.Content
        side=BaseUi.Types.Side.Top
        align=BaseUi.Types.Align.Start
        sideOffset=4.
        className="z-50 min-w-[190px] max-w-[min(280px,calc(100vw-16px))] bg-zinc-800 border border-zinc-700"
      >
        <Select.Group>
          {agents
          ->Array.map(agent =>
            <Select.Item
              key={agent.id}
              value={agent.id}
              label={agent.displayName}
              className="text-xs text-zinc-200 focus:bg-zinc-700 focus:text-white"
            >
              <span
                className="size-2 shrink-0 self-center rounded-full"
                style={{backgroundColor: agent.color}}
              />
              <span className="min-w-0 truncate"> {React.string(agent.displayName)} </span>
            </Select.Item>
          )
          ->React.array}
        </Select.Group>
      </Select.Content>
    </Select>
  }
}

module SelectElementButton = {
  @react.component
  let make = (
    ~onClick: unit => unit,
    ~isSelecting: bool,
    ~hasAnnotations: bool,
    ~showLabel: bool,
  ) => {
    let (extraClass, iconClass) = switch (isSelecting, hasAnnotations) {
    | (true, _) => ("text-violet-300 bg-violet-600/20 hover:bg-violet-600/30", "text-violet-300")
    | (false, true) => ("text-zinc-200 hover:bg-white/6", "text-zinc-200")
    | (false, false) => ("text-zinc-400 hover:text-zinc-200 hover:bg-white/6", "text-zinc-400")
    }

    <button
      type_="button"
      onClick={_ => onClick()}
      className={`inline-flex items-center gap-1.5 h-8 px-2.5 rounded-md text-xs font-medium
                 transition-colors cursor-pointer ${extraClass}`}
      title={isSelecting ? "Cancel selection" : "Select an element in the preview"}
    >
      {switch isSelecting {
      | true =>
        <span className="w-1.5 h-1.5 rounded-full bg-violet-400 animate-pulse flex-shrink-0" />
      | false => <Icons.CursorClickIcon size=13 className={iconClass} />
      }}
      {showLabel
        ? <span className="whitespace-nowrap">
            {React.string(isSelecting ? "Selecting\u{2026}" : "Select")}
          </span>
        : React.null}
      {switch (isSelecting, hasAnnotations) {
      | (false, true) =>
        <span
          className="w-1.5 h-1.5 rounded-full bg-violet-400 flex-shrink-0" title="Element selected"
        />
      | _ => React.null
      }}
    </button>
  }
}

module AttachButton = {
  @react.component
  let make = (~onClick: unit => unit, ~disabled: bool, ~showLabel: bool) => {
    <button
      type_="button"
      disabled
      onClick={_ => onClick()}
      className={`inline-flex items-center gap-1.5 h-8 ${showLabel
          ? "px-2.5"
          : "px-2"} rounded-md text-xs font-medium
                 transition-colors cursor-pointer text-zinc-400 hover:text-zinc-200 hover:bg-white/6
                 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent disabled:hover:text-zinc-400`}
      title="Attach files (images or PDFs up to 10MB)"
    >
      <Icons.PlusIcon size=13 className="text-zinc-400" />
      {showLabel
        ? <span className="whitespace-nowrap"> {React.string("Attach")} </span>
        : React.null}
    </button>
  }
}

module StopIcon = {
  @react.component
  let make = (~size: int=16) => {
    <svg
      width={Int.toString(size)}
      height={Int.toString(size)}
      viewBox="0 0 24 24"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
    >
      <rect x="6" y="6" width="12" height="12" rx="2" />
    </svg>
  }
}

module SubmitButton = {
  @react.component
  let make = (
    ~disabled: bool,
    ~showStop: bool,
    ~onClick: unit => unit,
    ~onCancel: unit => unit,
  ) => {
    if showStop {
      <button
        type_="button"
        onClick={e => {
          ReactEvent.Mouse.preventDefault(e)
          onCancel()
        }}
        className="inline-flex items-center gap-2 h-8 px-4 rounded-full
                   bg-[#985DF7] hover:bg-[#8247E5] text-white text-xs font-medium
                   transition-all hover:scale-105 cursor-pointer"
        title="Stop generation"
      >
        <StopIcon size=12 />
        <span> {React.string("Stop")} </span>
      </button>
    } else {
      <button
        type_="submit"
        disabled
        onClick={e => {
          ReactEvent.Mouse.preventDefault(e)
          onClick()
        }}
        className="flex items-center justify-center w-8 h-8 rounded-full
                   transition-all text-white cursor-pointer
                   bg-[#985DF7] hover:bg-[#8247E5] hover:scale-105
                   disabled:bg-zinc-700/50 disabled:text-zinc-500 disabled:cursor-not-allowed disabled:scale-100"
        title="Send (Enter)"
      >
        <Icons.SendArrowIcon size=14 />
      </button>
    }
  }
}

@react.component
let make = (
  ~onSubmit: (~text: string, ~inputItems: array<inputItem>) => unit,
  ~onCancel: unit => unit,
  ~modelConfigOption: option<ACP.sessionConfigOption>,
  ~isModelsConfigLoading: bool,
  ~selectedModelValue: option<ACP.sessionConfigValueId>,
  ~onModelChange: string => unit,
  ~agentCatalog: option<array<ACP.agentCatalogEntry>>,
  ~selectedAgentId: option<string>,
  ~onAgentChange: string => unit,
  ~onConfigureProvider: unit => unit,
  ~isAgentRunning: bool,
  ~hasActiveACPSession: bool,
  ~placeholder: string="What would you like to change?",
  ~disabled: bool=false,
  ~disabledPlaceholder: option<string>=?,
  ~onSelectElement: option<unit => unit>=?,
  ~isSelecting: bool=false,
  ~hasAnnotations: bool=false,
  ~isEnrichingAnnotations: bool=false,
) => {
  let (hasContent, setHasContent) = React.useState(() => false)
  let (hasComposerFocus, setHasComposerFocus) = React.useState(() => false)
  let (submitSignal, setSubmitSignal) = React.useState(() => 0)
  let (attachSignal, setAttachSignal) = React.useState(() => 0)
  let (dropFilesSignal, setDropFilesSignal) = React.useState(() => 0)
  let (droppedFiles, setDroppedFiles) = React.useState((): array<
    Client__PromptEditor.browserFile,
  > => [])
  let (previewSrc, setPreviewSrc) = React.useState((): option<string> => None)
  let (fileSizeError, setFileSizeError) = React.useState((): option<string> => None)
  let (showToolbarLabels, setShowToolbarLabels) = React.useState(() => true)
  let formRef = React.useRef(Nullable.null)
  let hasModelOptions =
    modelConfigOption->Option.flatMap(ACP.sessionConfigOptionFirstOption)->Option.isSome
  let noModelsConfigured =
    !isModelsConfigLoading && modelConfigOption->Option.isSome && !hasModelOptions
  let hasAgentSelector = switch (agentCatalog, selectedAgentId) {
  | (Some(agents), Some(_)) => agents->Array.length > 0
  | _ => false
  }
  let composerBorderColor = switch selectedAgentId {
  | Some(agentId) =>
    agentCatalog
    ->Option.flatMap(agents => agents->Array.find(agent => agent.id == agentId))
    ->Option.map(agent => `color-mix(in srgb, ${agent.color} 40%, transparent)`)
    ->Option.getOr("rgb(255 255 255 / 0.1)")
  | None => "rgb(255 255 255 / 0.1)"
  }

  let getDroppedFiles: ReactEvent.Mouse.t => array<Client__PromptEditor.browserFile> = %raw(`
    function(event) {
      var files = event.dataTransfer && event.dataTransfer.files;
      return files ? Array.from(files) : [];
    }
  `)

  let preventDefaultDropNavigation = (event: ReactEvent.Mouse.t) => {
    ReactEvent.Mouse.preventDefault(event)
    ReactEvent.Mouse.stopPropagation(event)
  }

  let _setupResizeObserver: (Dom.element, bool => unit) => unit => unit = %raw(`
    function(el, setShowLabel) {
      var LABEL_THRESHOLD = 300;
      var ro = new ResizeObserver(function(entries) {
        var width = entries[0].contentRect.width;
        setShowLabel(width >= LABEL_THRESHOLD);
      });
      ro.observe(el);
      return function() { ro.disconnect(); };
    }
  `)

  React.useEffect0(() => {
    formRef.current
    ->Nullable.toOption
    ->Option.map(el => _setupResizeObserver(el, v => setShowToolbarLabels(_ => v)))
  })

  React.useEffect1(() => {
    switch fileSizeError {
    | Some(_) =>
      let timeoutId = setTimeout(() => setFileSizeError(_ => None), 3000)
      Some(() => clearTimeout(timeoutId))
    | None => None
    }
  }, [fileSizeError])

  let doSubmit = () => setSubmitSignal(prev => prev + 1)
  let openAttachPicker = () => setAttachSignal(prev => prev + 1)
  let handleDrop = (event: ReactEvent.Mouse.t) => {
    preventDefaultDropNavigation(event)
    let files = getDroppedFiles(event)
    switch files->Array.length {
    | 0 => ()
    | _ =>
      setDroppedFiles(_ => files)
      setDropFilesSignal(prev => prev + 1)
    }
  }

  let handleEditorSubmit = (
    text,
    fileAttachments: array<Client__PromptEditor.editorFileAttachment>,
  ) => {
    let inputItems = fileAttachments->Array.map(file => FileAttachment({
      id: file.id,
      name: file.name,
      mediaType: file.mediaType,
      dataUrl: file.dataUrl,
    }))
    onSubmit(~text, ~inputItems)
    setHasContent(_ => false)
  }

  let hasSubmittableContent = hasContent || hasAnnotations
  let isInputDisabled = !hasActiveACPSession || disabled || noModelsConfigured
  let isSubmitDisabled = isInputDisabled || !hasSubmittableContent || isEnrichingAnnotations
  let showStopButton = isAgentRunning && !hasSubmittableContent

  let currentPlaceholder = if noModelsConfigured {
    "Connect an AI provider to start chatting."
  } else if disabled {
    disabledPlaceholder->Option.getOr("Input disabled")
  } else {
    placeholder
  }

  <div
    ref={ReactDOM.Ref.domRef(formRef)}
    className="bg-[#130d20] relative shrink-0"
    onDragOver={preventDefaultDropNavigation}
    onDrop={handleDrop}
  >
    {switch fileSizeError {
    | Some(error) =>
      <div className="px-3 pt-2">
        <div
          className="px-3 py-2 rounded-lg bg-red-900/40 border border-red-700/50 text-xs text-red-300"
        >
          {React.string(error)}
        </div>
      </div>
    | None => React.null
    }}

    <Client__BorderBeam
      size=#"pulse-outside"
      colorVariant=#ocean
      theme=#dark
      duration=2.8
      strength=0.85
      borderRadius=15.0
      active={isComposerBeamActive(~hasFocus=hasComposerFocus, ~isInputDisabled)}
      className="frontman-composer-beam mx-3 mb-2"
      onFocus={_ => setHasComposerFocus(_ => true)}
      onBlur={event =>
        switch ReactEvent.Focus.relatedTarget(event) {
        | Some(target)
          if WebAPI.Node.contains(
            ReactEvent.Focus.currentTarget(event)->Obj.magic->WebAPI.Element.asNode,
            target->Obj.magic->WebAPI.Element.asNode,
          ) => ()
        | _ => setHasComposerFocus(_ => false)
        }}
    >
      <div
        className="overflow-hidden rounded-xl border bg-white/[0.025] transition-colors
                   focus-within:ring-1 focus-within:ring-white/20"
        style={{borderColor: composerBorderColor}}
      >
        <div className="flex items-center px-2 py-1">
          <div
            className="flex flex-1 items-center gap-1 min-w-0 overflow-hidden transition-opacity"
          >
            <AttachButton
              onClick={openAttachPicker}
              disabled={isInputDisabled || isEnrichingAnnotations}
              showLabel={showToolbarLabels}
            />

            {switch onSelectElement {
            | Some(handler) =>
              <SelectElementButton
                onClick={handler}
                isSelecting={isSelecting}
                hasAnnotations={hasAnnotations}
                showLabel={showToolbarLabels}
              />
            | None => React.null
            }}
          </div>
        </div>

        <div className="border-t border-white/8">
          <Client__PromptEditor
            disabled={isInputDisabled}
            placeholder={currentPlaceholder}
            isEnrichingAnnotations
            hasAnnotations
            submitSignal
            attachSignal
            dropFilesSignal
            droppedFiles
            onHasContentChange={value => setHasContent(_ => value)}
            onSubmit={handleEditorSubmit}
            onPreviewImage={src => setPreviewSrc(_ => Some(src))}
            onFileSizeError={message => setFileSizeError(_ => Some(message))}
          />
        </div>

        <div className="flex min-w-0 items-center gap-2 border-t border-white/8 px-2 py-1">
          <div
            className={`grid min-w-0 flex-1 ${hasAgentSelector
                ? "grid-cols-2"
                : "grid-cols-1"} gap-2`}
          >
            {switch (agentCatalog, selectedAgentId) {
            | (Some(agents), Some(agentId)) if agents->Array.length > 0 =>
              <AgentSelector agents selectedAgentId={agentId} onAgentChange />
            | _ => React.null
            }}

            {switch (isModelsConfigLoading, modelConfigOption) {
            | (true, _) =>
              <div className="inline-flex h-9 min-w-0 items-center gap-1 px-2 text-xs">
                <span className="shrink-0 text-zinc-500"> {React.string("Model")} </span>
                <span className="shrink-0 text-zinc-600"> {React.string("\u{B7}")} </span>
                <span className="truncate text-zinc-500"> {React.string("Loading...")} </span>
              </div>
            | (false, Some(_)) if !hasModelOptions =>
              <button
                type_="button"
                onClick={_ => onConfigureProvider()}
                className="inline-flex h-9 min-w-0 items-center gap-1 rounded-md px-2 text-xs
                           text-violet-300 bg-violet-600/15 hover:bg-violet-600/25
                           transition-colors cursor-pointer"
              >
                <span className="shrink-0 text-zinc-500"> {React.string("Model")} </span>
                <span className="shrink-0 text-zinc-600"> {React.string("\u{B7}")} </span>
                <span className="truncate"> {React.string("Configure provider")} </span>
              </button>
            | (false, Some(configOption)) =>
              <div className="min-w-0 overflow-hidden">
                <ModelSelector
                  configOption selectedValue={selectedModelValue->Option.getOr("")} onModelChange
                />
              </div>
            | (false, None) => React.null
            }}
          </div>

          <SubmitButton
            disabled={isSubmitDisabled} showStop={showStopButton} onClick={doSubmit} onCancel
          />
        </div>
      </div>
    </Client__BorderBeam>

    {switch previewSrc {
    | Some(src) => <Client__ImagePreview src onClose={() => setPreviewSrc(_ => None)} />
    | None => React.null
    }}
  </div>
}
