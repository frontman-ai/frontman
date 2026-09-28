/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Headers)
*/
@new
external make: unit => FetchTypes.headers = "Headers"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Headers)
*/
@new
external fromDict: dict<string> => FetchTypes.headers = "Headers"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Headers)
*/
@new
external fromHeaders: FetchTypes.headers => FetchTypes.headers = "Headers"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Headers)
*/
@new
external fromKeyValueArray: array<(string, string)> => FetchTypes.headers = "Headers"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Headers/append)
*/
@send
external append: (FetchTypes.headers, ~name: string, ~value: string) => unit = "append"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Headers/delete)
*/
@send
external delete: (FetchTypes.headers, string) => unit = "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Headers/get)
*/
@send
external get: (FetchTypes.headers, string) => null<string> = "get"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Headers/getSetCookie)
*/
@send
external getSetCookie: FetchTypes.headers => array<string> = "getSetCookie"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Headers/has)
*/
@send
external has: (FetchTypes.headers, string) => bool = "has"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Headers/set)
*/
@send
external set: (FetchTypes.headers, ~name: string, ~value: string) => unit = "set"
