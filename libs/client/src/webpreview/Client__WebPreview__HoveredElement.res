@react.component
let make = (~element: option<Null.t<WebAPI.EventAPI.eventTarget>>, ~scrollTimestamp: float) => {
  let ((info, _scrollTimestamp), setInfo) = React.useState(() => (None, scrollTimestamp))

  React.useEffect(() => {
    switch element->Option.flatMap(Null.toOption) {
    | Some(target) => {
        let element = WebAPI.EventTarget.asElement(target)
        setInfo(_ => (Some(Client__WebPreview__Utils.getElementInfo(element)), scrollTimestamp))
      }
    | None => setInfo(_ => (None, scrollTimestamp))
    }
    None
  }, (element, scrollTimestamp, setInfo))

  info
  ->Option.map(info => {
    let rect = info.rect
    let label = Client__WebPreview__Utils.formatLabel(info)

    // Calculate label position - prefer top-left outside, but adjust if near edges
    let labelTop = rect.top > 24.0 ? rect.top -. 24.0 : rect.top +. rect.height +. 4.0

    // Highlight overlay with label
    <>
      <div
        style={
          position: "absolute",
          left: `${Float.toString(rect.left)}px`,
          top: `${Float.toString(rect.top)}px`,
          width: `${Float.toString(rect.width)}px`,
          height: `${Float.toString(rect.height)}px`,
          backgroundColor: "rgba(59, 130, 246, 0.08)",
          border: "1.5px solid rgba(59, 130, 246, 0.7)",
          borderRadius: "2px",
          pointerEvents: "none",
          zIndex: "9998",
          boxSizing: "border-box",
        }
      />
      <div
        style={
          position: "absolute",
          left: `${Float.toString(rect.left)}px`,
          top: `${Float.toString(labelTop)}px`,
          backgroundColor: "#3B82F6",
          color: "white",
          fontSize: "11px",
          fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
          fontWeight: "500",
          padding: "2px 6px",
          borderRadius: "3px",
          pointerEvents: "none",
          zIndex: "9999",
          whiteSpace: "nowrap",
          boxShadow: "0 1px 3px rgba(0,0,0,0.2)",
        }
      >
        {React.string(label)}
      </div>
    </>
  })
  ->Option.getOr(React.null)
}
