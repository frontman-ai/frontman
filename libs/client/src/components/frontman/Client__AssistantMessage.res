module MessageContainer = Client__MessageContainer
module Markdown = Client__Markdown
module Icons = Client__ToolIcons
module AgentChip = Client__AgentChip

type variant = Streaming | Completed

@react.component
let make = (~variant: variant, ~content: string, ~agent: Client__Agent.t, ~isNew: bool=false) => {
  let isStreaming = variant == Streaming

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
            title="Copy to clipboard"
            onClick={_ => {
              let _ = WebAPI.Global.navigator.clipboard->WebAPI.Clipboard.writeText(content)
            }}
          >
            <Icons.CopyIcon size=14 />
          </button>
        </div>
      : React.null}
  </MessageContainer>
}
