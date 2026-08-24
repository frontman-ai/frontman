let changeSummary = (fileChangeCount: int): string =>
  switch fileChangeCount {
  | 1 => "1 file changed"
  | count => `${Int.toString(count)} files changed`
  }

let updatingSummary = (fileChangeCount: int): string =>
  switch fileChangeCount {
  | 1 => "Updating: 1 file from completed turns"
  | count => `Updating: ${Int.toString(count)} files from completed turns`
  }

@react.component
let make = (
  ~view: Client__WorkspacePanel.view,
  ~fileChangeCount: int,
  ~isAgentRunning: bool,
  ~previewControls: React.element,
) =>
  <div className="flex items-center h-full flex-1 min-w-0 gap-1">
    {switch view {
    | Client__WorkspacePanel.Preview => previewControls
    | Client__WorkspacePanel.Changes =>
      <span className="px-2 text-xs text-zinc-500">
        {React.string(
          switch isAgentRunning {
          | true => updatingSummary(fileChangeCount)
          | false => changeSummary(fileChangeCount)
          },
        )}
      </span>
    }}
  </div>
