include EventTarget.Impl({type t = ClipboardTypes.clipboard})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clipboard/read)
*/
@send
external read: ClipboardTypes.clipboard => promise<array<ClipboardTypes.clipboardItem>> = "read"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clipboard/readText)
*/
@send
external readText: ClipboardTypes.clipboard => promise<string> = "readText"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clipboard/write)
*/
@send
external write: (ClipboardTypes.clipboard, array<ClipboardTypes.clipboardItem>) => promise<unit> =
  "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clipboard/writeText)
*/
@send
external writeText: (ClipboardTypes.clipboard, string) => promise<unit> = "writeText"

module ClipboardItem = ClipboardItem
module Types = ClipboardTypes
