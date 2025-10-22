open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly/getAll)
*/
@send
external getAll: (stylePropertyMapReadOnly, string) => array<cssStyleValue> = "getAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/StylePropertyMapReadOnly/has)
*/
@send
external has: (stylePropertyMapReadOnly, string) => bool = "has"
