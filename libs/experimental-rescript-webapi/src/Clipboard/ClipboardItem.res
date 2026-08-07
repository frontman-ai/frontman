@new
external make: (
  ~items: unknown,
  ~options: ClipboardTypes.clipboardItemOptions=?,
) => ClipboardTypes.clipboardItem = "ClipboardItem"

@send
external getType: (ClipboardTypes.clipboardItem, string) => promise<FileTypes.blob> = "getType"

@scope("ClipboardItem")
external supports: string => bool = "supports"
