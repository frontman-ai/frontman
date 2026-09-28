/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardItem)
*/
@new
external make: (
  ~items: unknown,
  ~options: ClipboardTypes.clipboardItemOptions=?,
) => ClipboardTypes.clipboardItem = "ClipboardItem"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardItem/getType)
*/
@send
external getType: (ClipboardTypes.clipboardItem, string) => promise<FileTypes.blob> = "getType"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardItem/supports_static)
*/
@scope("ClipboardItem")
external supports: string => bool = "supports"
