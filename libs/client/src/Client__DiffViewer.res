@@live

type fileContents = {
  name: string,
  contents: string,
}

type fileDiff

@module("@pierre/diffs")
external parseDiffFromFile: (Nullable.t<fileContents>, Nullable.t<fileContents>) => fileDiff =
  "parseDiffFromFile"

type options = {
  diffStyle: string,
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

  <FileDiff fileDiff options style />
}
