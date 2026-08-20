module FileChange = FrontmanAiFrontmanProtocol.FrontmanProtocol__FileChange
module Icons = Client__UI__Icons

let statusLabel = status =>
  switch status {
  | FileChange.Added => "Added"
  | FileChange.Modified => "Modified"
  | FileChange.Deleted => "Deleted"
  | FileChange.Renamed => "Renamed"
  }

let statusClass = status =>
  switch status {
  | FileChange.Added => "text-emerald-300 bg-emerald-500/10"
  | FileChange.Modified => "text-amber-300 bg-amber-500/10"
  | FileChange.Deleted => "text-rose-300 bg-rose-500/10"
  | FileChange.Renamed => "text-sky-300 bg-sky-500/10"
  }

let unavailableReasonLabel = (reason: Client__FileChanges.unavailableReason): string =>
  switch reason {
  | Client__FileChanges.Binary => "Text diff unavailable for binary files"
  | Client__FileChanges.SizeLimited => "Text diff unavailable because the file is too large"
  | Client__FileChanges.Discontinuous => "Text diff unavailable because recorded edits do not form a continuous history"
  }

module File = {
  @react.component
  let make = (~file: Client__FileChanges.file, ~revision: int) => {
    let (expanded, setExpanded) = React.useState(() => false)
    let rowId = `change-${Int.toString(revision)}-${file.path}`
    let pathLabel = switch file.oldPath {
    | Some(oldPath) => `${oldPath} → ${file.path}`
    | None => file.path
    }
    <section className="border-b border-white/8 last:border-b-0">
      <button
        type_="button"
        ariaExpanded={expanded}
        ariaControls={rowId}
        className="flex w-full items-center gap-2 px-4 py-3 text-left hover:bg-white/[0.03] transition-colors"
        onClick={_ => setExpanded(value => !value)}
      >
        <Icons.ChevronDown
          className={[
            "size-4 shrink-0 text-zinc-500 transition-transform",
            expanded ? "rotate-180" : "",
          ]->Array.join(" ")}
        />
        <span className="min-w-0 flex-1 truncate font-mono text-xs text-zinc-200">
          {React.string(pathLabel)}
        </span>
        {switch file.unavailableReason {
        | Some(_) => React.null
        | None =>
          <span className="shrink-0 font-mono text-xs">
            <span className="text-emerald-400">
              {React.string(`+${Int.toString(file.addedLines)}`)}
            </span>
            <span className="mx-1 text-zinc-600"> {React.string("/")} </span>
            <span className="text-rose-400">
              {React.string(`-${Int.toString(file.removedLines)}`)}
            </span>
          </span>
        }}
        <span
          className={`shrink-0 rounded px-1.5 py-0.5 text-[10px] font-medium ${statusClass(
              file.status,
            )}`}
        >
          {React.string(statusLabel(file.status))}
        </span>
      </button>
      {expanded
        ? <div id=rowId className="overflow-x-auto border-t border-white/8">
            {switch file.unavailableReason {
            | Some(reason) =>
              <div className="px-10 py-5 text-xs text-zinc-500">
                {React.string(unavailableReasonLabel(reason))}
              </div>
            | None =>
              <Client__DiffViewer
                path={file.path}
                oldPath={file.oldPath}
                oldText={file.oldText}
                newText={file.currentText}
              />
            }}
          </div>
        : React.null}
    </section>
  }
}

@react.component
let make = () => {
  let snapshot = Client__State.useSelector(Client__State.Selectors.completedFileChanges)
  let isAgentRunning = Client__State.useSelector(Client__State.Selectors.isAgentRunning)

  <div className="flex h-full min-h-0 flex-col bg-[#130d20] text-zinc-200">
    {isAgentRunning
      ? <div className="border-b border-white/8 bg-violet-500/5 px-4 py-2 text-xs text-violet-300">
          {React.string("Updates after this turn")}
        </div>
      : React.null}
    <div className="min-h-0 flex-1 overflow-y-auto">
      {switch snapshot.files {
      | [] =>
        <div
          className="flex h-full items-center justify-center px-6 text-center text-sm text-zinc-500"
        >
          {React.string("No recorded changes")}
        </div>
      | files =>
        <div key={Int.toString(snapshot.revision)}>
          {files
          ->Array.map(file =>
            <File
              key={`${Int.toString(snapshot.revision)}-${file.path}`}
              file
              revision=snapshot.revision
            />
          )
          ->React.array}
        </div>
      }}
    </div>
  </div>
}
