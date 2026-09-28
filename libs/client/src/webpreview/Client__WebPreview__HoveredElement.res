@react.component
let make = (
  ~element: option<WebAPI.DomTypes.element>,
  ~scrollTimestamp: float,
  ~mutationTimestamp: float=0.0,
) => {
  let (info, setInfo) = React.useState(() => None)
  let hasElement = element->Option.isSome

  React.useEffect(() => {
    switch element {
    | Some(element) => setInfo(_ => Some(Client__WebPreview__Utils.getElementInfo(element)))
    | None => ()
    }
    None
  }, (element, scrollTimestamp, mutationTimestamp))

  switch info {
  | Some(info) => {
      let rect = info.rect
      let label = Client__WebPreview__Utils.formatLabel(info)

      let labelTop = rect.top > 24.0 ? rect.top -. 24.0 : rect.top +. rect.height +. 4.0
      let opacity = hasElement ? "1" : "0"

      <>
        <div
          className="absolute bg-[#985DF7]/[0.08] border-[1.5px] border-[#985DF7]/70 rounded-sm pointer-events-none z-[9998] box-border transition-all duration-100 ease-out"
          style={
            left: `${Float.toString(rect.left)}px`,
            top: `${Float.toString(rect.top)}px`,
            width: `${Float.toString(rect.width)}px`,
            height: `${Float.toString(rect.height)}px`,
            opacity,
          }
        />
        <div
          className="absolute bg-[#985DF7] text-white text-[11px] font-mono font-medium px-1.5 py-0.5 rounded pointer-events-none z-[9999] whitespace-nowrap shadow transition-all duration-100 ease-out"
          style={
            left: `${Float.toString(rect.left)}px`,
            top: `${Float.toString(labelTop)}px`,
            opacity,
          }
        >
          {React.string(label)}
        </div>
      </>
    }
  | None => React.null
  }
}
