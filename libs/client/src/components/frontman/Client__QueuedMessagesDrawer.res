module UserContentPart = Client__State__Types.UserContentPart
module Message = Client__Message
module Icons = Client__ToolIcons

let previewForContent = (
  ~content: array<UserContentPart.t>,
  ~annotations: array<Message.MessageAnnotation.t>,
) => {
  let text =
    content
    ->Array.filterMap(part =>
      switch part {
      | UserContentPart.Text({text}) => Some(text)
      | _ => None
      }
    )
    ->Array.join(" ")
    ->String.trim

  switch text {
  | "" =>
    let imageCount =
      content
      ->Array.filter(part =>
        switch part {
        | UserContentPart.Image(_) => true
        | _ => false
        }
      )
      ->Array.length
    let fileCount =
      content
      ->Array.filter(part =>
        switch part {
        | UserContentPart.File(_) => true
        | _ => false
        }
      )
      ->Array.length
    let annotationCount = annotations->Array.length

    switch (imageCount, fileCount, annotationCount) {
    | (0, 0, 0) => "Queued message"
    | _ =>
      [
        imageCount > 0
          ? Some(`${imageCount->Int.toString} image${imageCount == 1 ? "" : "s"}`)
          : None,
        fileCount > 0 ? Some(`${fileCount->Int.toString} file${fileCount == 1 ? "" : "s"}`) : None,
        annotationCount > 0
          ? Some(`${annotationCount->Int.toString} annotation${annotationCount == 1 ? "" : "s"}`)
          : None,
      ]
      ->Array.filterMap(x => x)
      ->Array.join(" + ")
    }
  | text => text
  }
}

module QueuedRow = {
  @react.component
  let make = (~message: Message.t, ~index: int) =>
    switch message {
    | Message.User({content, annotations}) => {
        let preview = previewForContent(~content, ~annotations)
        <div className="flex items-start gap-2 rounded-md bg-zinc-950/35 px-2 py-1.5">
          <span className="mt-0.5 shrink-0 text-[10px] tabular-nums text-zinc-500">
            {React.string(`#${(index + 1)->Int.toString}`)}
          </span>
          <span className="min-w-0 flex-1 truncate text-[12px] leading-5 text-zinc-300">
            {React.string(preview)}
          </span>
          {switch annotations->Array.length > 0 {
          | true =>
            <span
              className="shrink-0 rounded bg-[#8051CD]/20 px-1.5 py-0.5 text-[10px] text-[#BFA6EA]"
            >
              {React.string(`${annotations->Array.length->Int.toString} mark`)}
            </span>
          | false => React.null
          }}
        </div>
      }
    | _ => failwith("[QueuedMessagesDrawer] queued message must be user-authored")
    }
}

@react.component
let make = (~messages: array<Message.t>) => {
  let count = messages->Array.length
  let (isExpanded, setIsExpanded) = React.useState(() => false)

  switch count {
  | 0 => React.null
  | _ => {
      let latest = messages->Array.get(count - 1)
      <div
        className="mx-3 mb-3 shrink-0 overflow-hidden rounded-lg border border-[#8051CD]/25 bg-[#201532]/80 shadow-sm"
      >
        <button
          type_="button"
          ariaExpanded={isExpanded}
          onClick={_ => setIsExpanded(prev => !prev)}
          className="flex w-full cursor-pointer items-center justify-between gap-3 px-3 py-2 text-left transition-colors hover:bg-white/[0.03]"
        >
          <div className="flex min-w-0 items-center gap-2">
            <Icons.ChevronDownIcon
              size=14
              className={`shrink-0 text-[#BFA6EA] transition-transform duration-150 ${isExpanded
                  ? ""
                  : "-rotate-90"}`}
            />
            <div className="min-w-0">
              <div className="text-[12px] font-medium text-zinc-200">
                {React.string(`Queued (${count->Int.toString})`)}
              </div>
              {switch latest {
              | Some(Message.User({content, annotations})) =>
                <div className="truncate text-[11px] text-zinc-500">
                  {React.string(previewForContent(~content, ~annotations))}
                </div>
              | _ => failwith("[QueuedMessagesDrawer] latest queued message must be user-authored")
              }}
            </div>
          </div>
          <div className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#8051CD]" />
        </button>
        {switch isExpanded {
        | false => React.null
        | true =>
          <div className="max-h-36 space-y-1 overflow-y-auto border-t border-white/5 p-2">
            {messages
            ->Array.mapWithIndex((message, index) => {
              <QueuedRow key={`queued-${index->Int.toString}`} message index />
            })
            ->React.array}
          </div>
        }}
      </div>
    }
  }
}
