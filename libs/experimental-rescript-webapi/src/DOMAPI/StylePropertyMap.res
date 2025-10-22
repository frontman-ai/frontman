open DOMAPI

external asStylePropertyMapReadOnly: stylePropertyMap => stylePropertyMapReadOnly = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly/getAll)
*/
@send
external getAll: (stylePropertyMap, string) => array<cssStyleValue> = "getAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly/has)
*/
@send
external has: (stylePropertyMap, string) => bool = "has"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/set)
*/
@send
external set: (stylePropertyMap, ~property: string, ~values: cssStyleValue) => unit = "set"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/set)
*/
@send
external set2: (stylePropertyMap, ~property: string, ~values: string) => unit = "set"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/append)
*/
@send
external append: (stylePropertyMap, ~property: string, ~values: cssStyleValue) => unit = "append"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/append)
*/
@send
external append2: (stylePropertyMap, ~property: string, ~values: string) => unit = "append"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/delete)
*/
@send
external delete: (stylePropertyMap, string) => unit = "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/clear)
*/
@send
external clear: stylePropertyMap => unit = "clear"
