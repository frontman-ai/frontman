/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly/getAll)
*/
@send
external getAll: (DomTypes.stylePropertyMapReadOnly, string) => array<DomTypes.cssStyleValue> =
  "getAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly/has)
*/
@send
external has: (DomTypes.stylePropertyMapReadOnly, string) => bool = "has"
