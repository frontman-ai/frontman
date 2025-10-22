open DOMAPI

external asHTMLCollection: htmlFormControlsCollection => htmlCollection = "%identity"
/**
Retrieves an object from various collections.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/item)
*/
@send
external item: (htmlFormControlsCollection, int) => element = "item"

/**
Retrieves a select object or an object from an options collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/namedItem)
*/
@send
external namedItem: (htmlFormControlsCollection, string) => element = "namedItem"
