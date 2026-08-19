@@live

type infiniteLoading = {
  pageSize: int,
  containerHeight: string,
  overscan: int,
}

type darkVariables = {
  diffViewerBackground: string,
  diffViewerColor: string,
  addedBackground: string,
  addedColor: string,
  removedBackground: string,
  removedColor: string,
  wordAddedBackground: string,
  wordRemovedBackground: string,
  addedGutterBackground: string,
  removedGutterBackground: string,
  gutterBackground: string,
  gutterBackgroundDark: string,
  gutterColor: string,
  codeFoldBackground: string,
  codeFoldGutterBackground: string,
  emptyLineBackground: string,
}

type variablesStyle = {dark: darkVariables}
type lineStyle = {fontFamily: string, fontSize: string, lineHeight: string}
type contentTextStyle = {padding: string}
type gutterStyle = {minWidth: string, padding: string}
type diffContainerStyle = {width: string}

type styles = {
  variables: variablesStyle,
  line: lineStyle,
  contentText: contentTextStyle,
  gutter: gutterStyle,
  diffContainer: diffContainerStyle,
}

let styles: styles = {
  variables: {
    dark: {
      diffViewerBackground: "#130d20",
      diffViewerColor: "#d4d4d8",
      addedBackground: "rgba(16, 185, 129, 0.12)",
      addedColor: "#d1fae5",
      removedBackground: "rgba(244, 63, 94, 0.12)",
      removedColor: "#ffe4e6",
      wordAddedBackground: "rgba(16, 185, 129, 0.28)",
      wordRemovedBackground: "rgba(244, 63, 94, 0.28)",
      addedGutterBackground: "rgba(16, 185, 129, 0.18)",
      removedGutterBackground: "rgba(244, 63, 94, 0.18)",
      gutterBackground: "#1c142b",
      gutterBackgroundDark: "#171020",
      gutterColor: "#71717a",
      codeFoldBackground: "#21182f",
      codeFoldGutterBackground: "#1c142b",
      emptyLineBackground: "#171020",
    },
  },
  line: {
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
    fontSize: "12px",
    lineHeight: "20px",
  },
  contentText: {padding: "0 10px"},
  gutter: {minWidth: "44px", padding: "0 8px"},
  diffContainer: {width: "100%"},
}

@react.component @module("react-diff-viewer-continued")
external make: (
  ~oldValue: string,
  ~newValue: string,
  ~splitView: bool=?,
  ~showDiffOnly: bool=?,
  ~extraLinesSurroundingDiff: int=?,
  ~useDarkTheme: bool=?,
  ~disableWordDiff: bool=?,
  ~hideSummary: bool=?,
  ~styles: styles=?,
  ~infiniteLoading: infiniteLoading=?,
) => React.element = "default"
