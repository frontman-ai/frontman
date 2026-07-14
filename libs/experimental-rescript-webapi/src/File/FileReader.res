type t

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileReader/FileReader)
*/
@new
external make: unit => t = "FileReader"

/**
Result is a string after `readAsDataURL` completes.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileReader/result)
*/
@get
external result: t => Null.t<string> = "result"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileReader/load_event)
*/
@set
external setOnload: (t, EventTypes.event => unit) => unit = "onload"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileReader/error_event)
*/
@set
external setOnerror: (t, EventTypes.event => unit) => unit = "onerror"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileReader/readAsDataURL)
*/
@send
external readAsDataURL: (t, FileTypes.blob) => unit = "readAsDataURL"
