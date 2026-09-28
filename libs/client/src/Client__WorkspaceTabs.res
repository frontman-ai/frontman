module Badge = Client__UI__Badge
module Button = Client__UI__Button

let selectView = (
  ~currentView: Client__WorkspacePanel.view,
  ~selectedView: Client__WorkspacePanel.view,
  ~onViewChange: Client__WorkspacePanel.view => unit,
) =>
  switch (currentView, selectedView) {
  | (Client__WorkspacePanel.Preview, Client__WorkspacePanel.Preview)
  | (Client__WorkspacePanel.Changes, Client__WorkspacePanel.Changes) => ()
  | (_, selectedView) => onViewChange(selectedView)
  }

let tabClassName = (~active) =>
  switch active {
  | true => "gap-1.5 rounded-md bg-white/10 text-zinc-100 hover:bg-white/10 cursor-pointer"
  | false => "gap-1.5 rounded-md text-zinc-500 hover:text-zinc-200 hover:bg-white/5 cursor-pointer"
  }

let ariaPressed = active =>
  switch active {
  | true => #"true"
  | false => #"false"
  }

@react.component
let make = (
  ~view: Client__WorkspacePanel.view,
  ~fileChangeCount: int,
  ~supportsChanges: bool,
  ~onViewChange: Client__WorkspacePanel.view => unit,
) => {
  let previewActive = switch view {
  | Client__WorkspacePanel.Preview => true
  | Client__WorkspacePanel.Changes => false
  }
  let changesActive = !previewActive
  let changesDisabled = switch fileChangeCount {
  | 0 => true
  | _ => false
  }

  <div className="flex items-center h-full shrink-0 gap-0.5">
    <Button
      variant=Button.Variant.Ghost
      size=Button.Size.Xs
      ariaPressed={ariaPressed(previewActive)}
      onClick={_ =>
        selectView(~currentView=view, ~selectedView=Client__WorkspacePanel.Preview, ~onViewChange)}
      className={tabClassName(~active=previewActive)}
    >
      {React.string("Preview")}
    </Button>
    {switch supportsChanges {
    | false => React.null
    | true =>
      <Button
        variant=Button.Variant.Ghost
        size=Button.Size.Xs
        ariaPressed={ariaPressed(changesActive)}
        disabled=changesDisabled
        onClick={_ =>
          selectView(
            ~currentView=view,
            ~selectedView=Client__WorkspacePanel.Changes,
            ~onViewChange,
          )}
        className={tabClassName(~active=changesActive)}
      >
        <span> {React.string("Changes")} </span>
        <Badge
          variant=Badge.Variant.Secondary
          className="h-4 min-w-4 rounded-full bg-violet-500/20 px-1 text-[10px] text-violet-200"
        >
          {React.int(fileChangeCount)}
        </Badge>
      </Button>
    }}
  </div>
}
