open ClipboardAPI

include EventTarget.Impl({type t = clipboard})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clipboard/read)
*/
@send
external read: clipboard => promise<array<clipboardItem>> = "read"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clipboard/readText)
*/
@send
external readText: clipboard => promise<string> = "readText"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clipboard/write)
*/
@send
external write: (clipboard, array<clipboardItem>) => promise<unit> = "write"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Clipboard/writeText)
*/
@send
external writeText: (clipboard, string) => promise<unit> = "writeText"
