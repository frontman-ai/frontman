open FileAPI
open ClipboardAPI
open Prelude

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardItem)
*/
@new
external make: (~items: any, ~options: clipboardItemOptions=?) => clipboardItem = "ClipboardItem"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardItem/getType)
*/
@send
external getType: (clipboardItem, string) => promise<blob> = "getType"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardItem/supports_static)
*/
@scope("ClipboardItem")
external supports: string => bool = "supports"
