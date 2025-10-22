open DOMAPI

/**
Retrieves a select object or an object from an options collection.
@param name Variant of type Number or String that specifies the object or collection to retrieve. If this parameter is an integer, it is the zero-based index of the object. If this parameter is a string, all objects with matching name or id properties are retrieved, and a collection is returned if more than one match is made.
@param index Variant of type Number that specifies the zero-based index of the object to retrieve when a collection is returned.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/item)
*/
@send
external item: (htmlSelectElement, int) => htmlOptionElement = "item"

/**
Retrieves a select object or an object from an options collection.
@param namedItem A String that specifies the name or id property of the object to retrieve. A collection is returned if more than one match is made.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/namedItem)
*/
@send
external namedItem: (htmlSelectElement, string) => htmlOptionElement = "namedItem"

/**
Adds an element to the areas, controlRange, or options collection.
@param element Variant of type Number that specifies the index position in the collection where the element is placed. If no value is given, the method places the element at the end of the collection.
@param before Variant of type Object that specifies an element to insert before, or null to append the object to the collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/add)
*/
@send
external add: (htmlSelectElement, ~element: unknown, ~before: unknown=?) => unit = "add"

/**
Removes an element from the collection.
@param index Number that specifies the zero-based index of the element to remove from the collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/remove)
*/
@send
external removeH: htmlSelectElement => unit = "remove"

/**
Removes an element from the collection.
@param index Number that specifies the zero-based index of the element to remove from the collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/remove)
*/
@send
external removeH2: (htmlSelectElement, int) => unit = "remove"

/**
Returns whether a form will validate when it is submitted, without having to submit it.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/checkValidity)
*/
@send
external checkValidity: htmlSelectElement => bool = "checkValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/reportValidity)
*/
@send
external reportValidity: htmlSelectElement => bool = "reportValidity"

/**
Sets a custom error message that is displayed when a form is submitted.
@param error Sets a custom error message that is displayed when a form is submitted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/setCustomValidity)
*/
@send
external setCustomValidity: (htmlSelectElement, string) => unit = "setCustomValidity"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLSelectElement/showPicker)
*/
@send
external showPicker: htmlSelectElement => unit = "showPicker"

include HTMLElement.Impl({type t = htmlSelectElement})
