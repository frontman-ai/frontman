open DOMAPI

/**
Inserts element before the node given by before.

The before argument can be a number, in which case element is inserted before the item with that number, or an element from the collection, in which case element is inserted before that element.

If before is omitted, null, or a number out of range, then element will be added at the end of the list.

This method will throw a "HierarchyRequestError" DOMException if element is an ancestor of the element into which it is to be inserted.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionsCollection/add)
*/
@send
external add: (htmlOptionsCollection, ~element: unknown, ~before: unknown=?) => unit = "add"

/**
Removes the item with index index from the collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/HTMLOptionsCollection/remove)
*/
@send
external remove: (htmlOptionsCollection, int) => unit = "remove"
