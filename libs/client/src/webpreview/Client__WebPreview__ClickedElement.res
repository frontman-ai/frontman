@react.component
let make = (
  ~element: WebAPI.DOMAPI.element,
  ~scrollTimestamp: float,
  ~mutationTimestamp: float,
) => {
  let ((rect, _scrollTimestamp, _mutationTimestamp), setRect) = React.useState(() => (
    None,
    scrollTimestamp,
    mutationTimestamp,
  ))

  React.useEffect(() => {
    let boundingRect = WebAPI.Element.getBoundingClientRect(element)
    setRect(_ => (Some(boundingRect), scrollTimestamp, mutationTimestamp))
    None
  }, (element, scrollTimestamp, mutationTimestamp, setRect))

  rect
  ->Option.map(rect => {
    // Selection border only - no label (label is shown on hover instead)
    <div
      style={
        position: "absolute",
        left: `${Float.toString(rect.left)}px`,
        top: `${Float.toString(rect.top)}px`,
        width: `${Float.toString(rect.width)}px`,
        height: `${Float.toString(rect.height)}px`,
        border: "2px solid #3B82F6",
        borderRadius: "2px",
        pointerEvents: "none",
        zIndex: "9999",
        boxSizing: "border-box",
        boxShadow: "0 0 0 1px rgba(59, 130, 246, 0.3)",
      }
    />
  })
  ->Option.getOr(React.null)
}
