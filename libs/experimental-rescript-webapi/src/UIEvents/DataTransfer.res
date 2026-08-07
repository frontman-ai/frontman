@new
external make: unit => UiEventsTypes.dataTransfer = "DataTransfer"

@send
external setDragImage: (
  UiEventsTypes.dataTransfer,
  ~image: DomTypes.element,
  ~x: int,
  ~y: int,
) => unit = "setDragImage"

@send
external getData: (UiEventsTypes.dataTransfer, string) => string = "getData"

@send
external setData: (UiEventsTypes.dataTransfer, ~format: string, ~data: string) => unit = "setData"

@send
external clearData: (UiEventsTypes.dataTransfer, ~format: string=?) => unit = "clearData"
