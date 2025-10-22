open DOMAPI

/**
Retrieves an object from various collections.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/item)
*/
@send
external item: (htmlCollection, int) => element = "item"

/**
Retrieves a select object or an object from an options collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/namedItem)
*/
@send
external namedItem: (htmlCollection, string) => element = "namedItem"
