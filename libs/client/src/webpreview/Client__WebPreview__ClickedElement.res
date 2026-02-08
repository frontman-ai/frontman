@react.component
let make = (
  ~element: WebAPI.DOMAPI.element,
  ~scrollTimestamp: float,
  ~mutationTimestamp: float,
  ~isScanning: bool=false,
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
    // Note: position/size must remain inline styles since they're dynamic values
    <div
      className={`absolute border-2 border-[#985DF7] rounded-sm pointer-events-none z-[9999] box-border ring-1 ring-[#985DF7]/30 ${isScanning ? "frontman-scanning" : ""}`}
      style={
        left: `${Float.toString(rect.left)}px`,
        top: `${Float.toString(rect.top)}px`,
        width: `${Float.toString(rect.width)}px`,
        height: `${Float.toString(rect.height)}px`,
      }
    />
  })
  ->Option.getOr(React.null)
}
