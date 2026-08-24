/**
 * ToolCallBlock - Main tool call display component
 *
 * Supports compact mode for grouped display and expand/collapse for details.
 */
module Message = Client__State__Types.Message
module ToolLabels = Client__ToolLabels
module ToolNames = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool.ToolNames
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

let cleanToolName = (toolName: string): string => String.toLowerCase(toolName)

let isInlineTool = (toolName: string): bool => {
  let name = cleanToolName(toolName)
  switch name {
  | "read_file" | "write_file" | "list_files" | "list_dir" => true
  | _ => false
  }
}

let renderContent = (item, setPreviewSrc) =>
  switch item {
  | ACP.Content({content: TextContent({text})}) =>
    <pre className="whitespace-pre-wrap break-words"> {React.string(text)} </pre>
  | Content({content: ImageContent({data, mimeType})}) => {
      let src = `data:${mimeType};base64,${data}`
      <button
        type_="button"
        ariaLabel="View image output"
        onClick={event => {
          ReactEvent.Mouse.stopPropagation(event)
          setPreviewSrc(_ => Some(src))
        }}
        className="block cursor-zoom-in"
      >
        <img src alt="Tool output" className="max-h-32 rounded border border-[#8051CD]/30" />
      </button>
    }
  | Content({content: AudioContent({data, mimeType})}) =>
    <audio controls=true src={`data:${mimeType};base64,${data}`} className="max-w-full" />
  | Content({content: ResourceLink({name, uri})}) =>
    <div className="font-mono text-zinc-400"> {React.string(`${name}: ${uri}`)} </div>
  | Content({content: EmbeddedResource({resource: TextResourceContents({uri, text})})}) =>
    <pre> {React.string(`${uri}\n${text}`)} </pre>
  | Content({
      content: EmbeddedResource({resource: BlobResourceContents({uri, mimeType, blob})}),
    }) => {
      let src = `data:${mimeType->Option.getOr("application/octet-stream")};base64,${blob}`
      <a href=src download=uri> {React.string(`Download ${uri}`)} </a>
    }
  | Diff({path}) => <div className="font-mono text-zinc-400"> {React.string(`Diff: ${path}`)} </div>
  | Terminal({terminalId}) => <div> {React.string(`Terminal ${terminalId}`)} </div>
  }

let getTarget = (toolName: string, input: option<JSON.t>): option<string> => {
  switch ToolLabels.extractTargetFromInput(input) {
  | Some(".") => Some("./")
  | Some(t) => Some(t)
  | None if isInlineTool(toolName) => Some("./")
  | None => None
  }
}

@react.component
let make = (
  ~toolName: string,
  ~state: Message.toolCallState,
  ~input: option<JSON.t>,
  ~inputBuffer: string,
  ~result: option<Message.toolResult>,
  ~errorText: option<string>,
  ~defaultExpanded: bool=false,
  ~compact: bool=false,
) => {
  switch cleanToolName(toolName) == ToolNames.question {
  | true => <Client__QuestionToolBlock state input result errorText />
  | false =>
    let isLink = isInlineTool(toolName)
    let (isExpanded, setIsExpanded) = React.useState(() => defaultExpanded)
    let wasManuallyToggled = React.useRef(false)
    let (previewSrc, setPreviewSrc) = React.useState((): option<string> => None)

    React.useEffect(() => {
      if !wasManuallyToggled.current {
        setIsExpanded(_ => defaultExpanded)
      }
      None
    }, [defaultExpanded])

    let target = getTarget(toolName, input)
    let isInProgress = state == InputStreaming || state == InputAvailable
    let hasError = Option.isSome(errorText)

    let hasBody =
      !isLink &&
      ((state == InputStreaming && inputBuffer != "") ||
      Option.isSome(input) ||
      Option.isSome(result) ||
      Option.isSome(errorText))

    let handleToggle = _ => {
      if hasBody {
        setIsExpanded(prev => !prev)
        wasManuallyToggled.current = true
      }
    }

    let containerClasses =
      [
        "group overflow-hidden",
        "animate-in fade-in duration-100",
        compact ? "rounded-lg" : "my-1.5 rounded-xl",
        compact ? "bg-[#8051CD]/15" : "bg-[#8051CD]/20",
        compact ? "border border-[#8051CD]/30" : "border border-[#8051CD]/40",
        compact ? "px-3 py-2" : "px-4 py-3",
        hasBody ? "cursor-pointer" : "",
      ]
      ->Array.filter(s => s != "")
      ->Array.join(" ")

    let bodyClasses =
      [
        "overflow-hidden frontman-collapse-transition",
        isExpanded ? "max-h-[300px] opacity-100" : "max-h-0 opacity-0",
      ]->Array.join(" ")

    <div className={containerClasses}>
      <div onClick={handleToggle}>
        <div className={`font-mono ${compact ? "text-[12px]" : "text-[13px]"}`}>
          <span className={isInProgress ? "shimmer-text text-zinc-200" : "text-zinc-200"}>
            {React.string(ToolLabels.toTitleCase(toolName))}
          </span>
        </div>

        {switch (target, state, input) {
        | (_, InputStreaming, None) if isLink => {
            let placeholder = "Waiting for file path..."
            <div className={`mt-1 ${compact ? "text-[11px]" : "text-[12px]"}`}>
              <span className="font-mono shimmer-text text-zinc-500">
                {React.string(placeholder)}
              </span>
            </div>
          }
        | (Some(t), _, _) =>
          <div className={`mt-1 min-w-0 ${compact ? "text-[11px]" : "text-[12px]"}`}>
            <span
              title=t
              className={`block max-w-full truncate font-mono ${hasError
                  ? "text-red-400"
                  : "text-[#8051CD] hover:text-[#9d7be0]"}`}
            >
              {React.string(t)}
            </span>
          </div>
        | _ => React.null
        }}

        {switch errorText {
        | Some(err) =>
          <div
            title=err
            className="mt-2 min-w-0 whitespace-pre-wrap break-words text-[11px] text-red-400 font-mono"
          >
            {React.string(err)}
          </div>
        | None => React.null
        }}
      </div>

      {hasBody
        ? <div className={bodyClasses}>
            <div
              className={`mt-3 pt-3 border-t border-[#8051CD]/20 overflow-auto ${compact
                  ? "max-h-[120px] text-[10px]"
                  : "max-h-[150px] text-xs"}`}
            >
              {switch (state, input, inputBuffer) {
              | (InputStreaming, None, buf) if buf != "" =>
                <div className="mb-2">
                  <div className="text-[11px] text-zinc-500 mb-1">
                    {React.string("Input (streaming):")}
                  </div>
                  <pre
                    className="font-mono text-[11px] whitespace-pre-wrap break-words text-zinc-400"
                  >
                    {React.string(buf)}
                  </pre>
                </div>
              | (_, Some(json), _) =>
                <div className="mb-2">
                  <div className="text-[11px] text-zinc-500 mb-1"> {React.string("Input:")} </div>
                  <pre
                    className="font-mono text-[11px] whitespace-pre-wrap break-words text-zinc-400"
                  >
                    {React.string(JSON.stringify(json, ~space=2))}
                  </pre>
                </div>
              | _ => React.null
              }}
              {switch result {
              | Some({content}) if content->Array.length > 0 =>
                <div className="font-mono text-[11px] text-zinc-400">
                  <div className="text-[11px] text-zinc-500 mb-1"> {React.string("Output:")} </div>
                  {content
                  ->Array.mapWithIndex((item, index) =>
                    <div key={index->Int.toString}> {renderContent(item, setPreviewSrc)} </div>
                  )
                  ->React.array}
                </div>
              | None if Option.isSome(errorText) => React.null
              | _ if state == InputAvailable =>
                <div className="text-sm text-zinc-400 italic py-1">
                  {React.string("Executing...")}
                </div>
              | _ => React.null
              }}
            </div>
          </div>
        : React.null}

      {switch previewSrc {
      | Some(src) => <Client__ImagePreview src onClose={() => setPreviewSrc(_ => None)} />
      | None => React.null
      }}
    </div>
  }
}
let make = React.memo(make)
