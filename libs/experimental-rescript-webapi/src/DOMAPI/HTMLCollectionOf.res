open DOMAPI

external asHTMLCollection: htmlCollectionOf<'t> => htmlCollection = "%identity"
/**
Retrieves an object from various collections.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/item)
*/
@send
external item: (htmlCollectionOf<'t>, int) => element = "item"

/**
Retrieves a select object or an object from an options collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/namedItem)
*/
@send
external namedItem: (htmlCollectionOf<'t>, string) => element = "namedItem"
