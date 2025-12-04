@react.component
let make = (~element: option<Null.t<WebAPI.EventAPI.eventTarget>>, ~scrollTimestamp: float) => {
  let ((rect, _scrollTimestamp), setRect) = React.useState(() => (None, scrollTimestamp))

  React.useEffect(() => {
    element
    ->Option.flatMap(Null.toOption)
    ->Option.forEach(target => {
      let element = WebAPI.EventTarget.asElement(target)
      let boundingRect = WebAPI.Element.getBoundingClientRect(element)
      setRect(_ => (Some(boundingRect), scrollTimestamp))
    })
    None
  }, (element, scrollTimestamp, setRect))

  rect
  ->Option.map(rect => {
    <div
      style={
        position: "absolute",
        left: `${Float.toString(rect.left)}px`,
        top: `${Float.toString(rect.top)}px`,
        width: `${Float.toString(rect.width)}px`,
        height: `${Float.toString(rect.height)}px`,
        backgroundColor: "rgba(255, 255, 0, 0.3)",
        pointerEvents: "none",
        zIndex: "9998",
      }
    />
  })
  ->Option.getOr(React.null)
}
