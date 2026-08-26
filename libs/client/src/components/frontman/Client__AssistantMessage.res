/**
 * AssistantMessage - Renders assistant messages with markdown and copy action
 */
module MessageContainer = Client__MessageContainer
module Markdown = Client__Markdown
module Icons = Client__ToolIcons
module AgentChip = Client__AgentChip

type variant = Streaming | Completed

@react.component
let make = (~variant: variant, ~content: string, ~agent: Client__Agent.t, ~isNew: bool=false) => {
  let isStreaming = variant == Streaming
  let (isCopied, setIsCopied) = React.useState(() => false)
  let copiedTimeoutRef: React.ref<option<WebAPI.DomTypes.timeoutId>> = React.useRef(None)

  let resetCopied = () => {
    copiedTimeoutRef.current->Option.forEach(timeout =>
      WebAPI.Window.clearTimeout(WebAPI.Window.current, timeout)
    )
    copiedTimeoutRef.current = None
    setIsCopied(_ => false)
  }

  <MessageContainer isNew isStreaming className="group relative">
    <div className="absolute left-1 z-10">
      <AgentChip agent />
    </div>
    <div className="text-[13px] leading-relaxed pt-8 text-zinc-300 font-ibm-plex-mono">
      <Markdown className="size-full [&>*:first-child]:mt-0 [&>*:last-child]:mb-0">
        {content}
      </Markdown>
    </div>

    {!isStreaming && content != ""
      ? <div
          className="absolute bottom-1.5 right-2 flex items-center gap-1 opacity-0 group-hover:opacity-100 focus-within:opacity-100 transition-opacity z-10"
        >
          <button
            type_="button"
            className="flex items-center justify-center w-5 h-5 border-none bg-transparent rounded cursor-pointer opacity-50 hover:opacity-80 transition-opacity text-zinc-200"
            title={isCopied ? "Copied" : "Copy to clipboard"}
            onClick={_ => {
              let copy = async () => {
                await
                WebAPI.Window.current
                ->WebAPI.Window.navigator
                ->WebAPI.Navigator.clipboard
                ->WebAPI.Clipboard.writeText(content)
                setIsCopied(_ => true)
                copiedTimeoutRef.current->Option.forEach(timeout =>
                  WebAPI.Window.clearTimeout(WebAPI.Window.current, timeout)
                )
                copiedTimeoutRef.current = Some(
                  WebAPI.Window.setTimeout(
                    WebAPI.Window.current,
                    ~handler=resetCopied,
                    ~timeout=2000,
                  ),
                )
              }
              copy()->ignore
            }}
          >
            {isCopied ? <Icons.CheckIcon size=14 /> : <Icons.CopyIcon size=14 />}
          </button>
        </div>
      : React.null}
  </MessageContainer>
}
