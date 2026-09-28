external asHTMLCollection: DomTypes.htmlFormControlsCollection => DomTypes.htmlCollection<
  DomTypes.element,
> = "%identity"
/**
Retrieves an object from various collections.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/item)
*/
@send
external item: (DomTypes.htmlFormControlsCollection, int) => DomTypes.element = "item"

/**
Retrieves a select object or an object from an options collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLCollection/namedItem)
*/
@send
external namedItem: (DomTypes.htmlFormControlsCollection, string) => DomTypes.element = "namedItem"
