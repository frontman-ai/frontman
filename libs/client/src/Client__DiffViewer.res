@@live

type fileContents = {
  name: string,
  contents: string,
}

type fileDiff

type highlighterOptions = {
  themes: array<string>,
  langs: array<string>,
}

type highlighterState = Loading | Ready(string) | Failed(string, string)

@module("@pierre/diffs")
external parseDiffFromFile: (Nullable.t<fileContents>, Nullable.t<fileContents>) => fileDiff =
  "parseDiffFromFile"

@module("@pierre/diffs")
external getFiletypeFromFileName: string => string = "getFiletypeFromFileName"

@module("@pierre/diffs")
external preloadHighlighter: highlighterOptions => promise<unit> = "preloadHighlighter"

type options = {
  diffStyle: string,
  theme: string,
  themeType: string,
  hunkSeparators: string,
  lineDiffType: string,
  diffIndicators: string,
  disableFileHeader: bool,
  collapsedContextThreshold: int,
  expansionLineCount: int,
  overflow: string,
}

let options: options = {
  diffStyle: "unified",
  theme: "pierre-dark",
  themeType: "dark",
  hunkSeparators: "line-info",
  lineDiffType: "word",
  diffIndicators: "bars",
  disableFileHeader: true,
  collapsedContextThreshold: 3,
  expansionLineCount: 20,
  overflow: "scroll",
}

let style =
  ({}: ReactDOM.Style.t)
  ->ReactDOM.Style.unsafeAddProp("--diffs-dark-bg", "#130d20")
  ->ReactDOM.Style.unsafeAddProp("--diffs-font-size", "12px")
  ->ReactDOM.Style.unsafeAddProp("--diffs-line-height", "20px")

module FileDiff = {
  @react.component @module("@pierre/diffs/react")
  external make: (
    ~fileDiff: fileDiff,
    ~options: options=?,
    ~className: string=?,
    ~style: ReactDOM.Style.t=?,
  ) => React.element = "FileDiff"
}

@react.component
let make = (
  ~path: string,
  ~oldPath: option<string>,
  ~oldText: option<string>,
  ~newText: option<string>,
) => {
  let (highlighterState, setHighlighterState) = React.useState(() => Loading)

  React.useEffect(() => {
    let active = ref(true)
    preloadHighlighter({
      themes: [options.theme],
      langs: [getFiletypeFromFileName(path)],
    })
    ->Promise.then(_ => {
      switch active.contents {
      | true => setHighlighterState(_ => Ready(path))
      | false => ()
      }
      Promise.resolve()
    })
    ->Promise.catch(error => {
      let message =
        error
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Diff highlighter failed to load")
      switch active.contents {
      | true => setHighlighterState(_ => Failed(path, message))
      | false => ()
      }
      Promise.resolve()
    })
    ->ignore
    Some(() => active := false)
  }, [path])

  let fileDiff = React.useMemo4(() => {
    let oldFile = switch oldText {
    | Some(contents) => Nullable.make({name: oldPath->Option.getOr(path), contents})
    | None => Nullable.null
    }
    let newFile = switch newText {
    | Some(contents) => Nullable.make({name: path, contents})
    | None => Nullable.null
    }
    parseDiffFromFile(oldFile, newFile)
  }, (path, oldPath, oldText, newText))

  switch highlighterState {
  | Ready(readyPath) if readyPath == path => <FileDiff fileDiff options style />
  | Failed(failedPath, message) if failedPath == path => JsError.throwWithMessage(message)
  | Loading | Ready(_) | Failed(_, _) =>
    <div className="flex items-center justify-center gap-2 px-4 py-6 text-xs text-zinc-500">
      <Client__UI__Spinner className="size-3.5" />
      <span> {React.string("Preparing diff")} </span>
    </div>
  }
}
