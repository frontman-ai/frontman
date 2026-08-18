/**
Retrieves an object from various collections.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/item)
*/
@send
external item: (DomTypes.htmlCollection<'t>, int) => Null.t<'t> = "item"

/**
Retrieves a select object or an object from an options collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/namedItem)
*/
@send
external namedItem: (DomTypes.htmlCollection<'t>, string) => Null.t<'t> = "namedItem"

/** Returns a new array containing the elements in the collection. */
@scope("Array") @val
external toArray: DomTypes.htmlCollection<'t> => array<'t> = "from"
