open URLAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL)
*/
@new
external make: (~url: string, ~base: string=?) => url = "URL"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/parse_static)
*/
@scope("URL")
external parse: (~url: string, ~base: string=?) => url = "parse"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/canParse_static)
*/
@scope("URL")
external canParse: (~url: string, ~base: string=?) => bool = "canParse"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/toJSON)
*/
@send
external toJSON: url => string = "toJSON"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/createObjectURL_static)
*/
@scope("URL")
external createObjectURL: unknown => string = "createObjectURL"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/URL/revokeObjectURL_static)
*/
@scope("URL")
external revokeObjectURL: string => unit = "revokeObjectURL"
