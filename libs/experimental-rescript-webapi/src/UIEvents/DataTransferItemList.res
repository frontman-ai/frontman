@send
external item: (UiEventsTypes.dataTransferItemList, int) => UiEventsTypes.dataTransferItem = "item"

@get_index
external get: (UiEventsTypes.dataTransferItemList, int) => UiEventsTypes.dataTransferItem = ""

@send
external add: (
  UiEventsTypes.dataTransferItemList,
  ~data: string,
  ~type_: string,
) => UiEventsTypes.dataTransferItem = "add"

@send
external addFile: (
  UiEventsTypes.dataTransferItemList,
  FileTypes.file,
) => UiEventsTypes.dataTransferItem = "add"

@send
external remove: (UiEventsTypes.dataTransferItemList, int) => unit = "remove"

@send
external clear: UiEventsTypes.dataTransferItemList => unit = "clear"
