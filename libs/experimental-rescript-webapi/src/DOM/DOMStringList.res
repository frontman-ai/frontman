type t = DOM.domStringList

/**
Returns the string with index index from strings.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMStringList/item)
*/
@send
external item: (t, int) => string = "item"

/**
Returns true if strings contains string, and false otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMStringList/contains)
*/
@send
external contains: (t, string) => bool = "contains"
