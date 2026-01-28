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
    // Note: position/size must remain inline styles since they're dynamic values
    <>
      <div
        className="absolute bg-blue-500/[0.08] border-[1.5px] border-blue-500/70 rounded-sm pointer-events-none z-[9998] box-border"
        style={
          left: `${Float.toString(rect.left)}px`,
          top: `${Float.toString(rect.top)}px`,
          width: `${Float.toString(rect.width)}px`,
          height: `${Float.toString(rect.height)}px`,
        }
      />
      <div
        className="absolute bg-blue-500 text-white text-[11px] font-mono font-medium px-1.5 py-0.5 rounded pointer-events-none z-[9999] whitespace-nowrap shadow"
        style={
          left: `${Float.toString(rect.left)}px`,
          top: `${Float.toString(labelTop)}px`,
        }
      >
        {React.string(label)}
      </div>
    </>
  })
  ->Option.getOr(React.null)
}
