open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaList/item)
*/
@send
external item: (mediaList, int) => string = "item"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaList/appendMedium)
*/
@send
external appendMedium: (mediaList, string) => unit = "appendMedium"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/MediaList/deleteMedium)
*/
@send
external deleteMedium: (mediaList, string) => unit = "deleteMedium"
