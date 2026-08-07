external asStylePropertyMapReadOnly: DomTypes.stylePropertyMap => DomTypes.stylePropertyMapReadOnly =
  "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly/getAll)
*/
@send
external getAll: (DomTypes.stylePropertyMap, string) => array<DomTypes.cssStyleValue> = "getAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly/has)
*/
@send
external has: (DomTypes.stylePropertyMap, string) => bool = "has"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/set)
*/
@send
external set: (
  DomTypes.stylePropertyMap,
  ~property: string,
  ~values: DomTypes.cssStyleValue,
) => unit = "set"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/set)
*/
@send
external set2: (DomTypes.stylePropertyMap, ~property: string, ~values: string) => unit = "set"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/append)
*/
@send
external append: (
  DomTypes.stylePropertyMap,
  ~property: string,
  ~values: DomTypes.cssStyleValue,
) => unit = "append"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/append)
*/
@send
external append2: (DomTypes.stylePropertyMap, ~property: string, ~values: string) => unit = "append"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/delete)
*/
@send
external delete: (DomTypes.stylePropertyMap, string) => unit = "delete"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMap/clear)
*/
@send
external clear: DomTypes.stylePropertyMap => unit = "clear"
