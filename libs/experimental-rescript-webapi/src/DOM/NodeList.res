/**
Returns the node with index index from the collection. The nodes are sorted in tree order.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeList/item)
*/
@send
external item: (DomTypes.nodeList<'tNode>, int) => Null.t<'tNode> = "item"

/**
Calls callback once for each node in the collection.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeList/forEach)
*/
@send
external forEach: (DomTypes.nodeList<'tNode>, 'tNode => unit) => unit = "forEach"

/** Returns a new array containing the nodes in the collection. */
@scope("Array") @val
external toArray: DomTypes.nodeList<'tNode> => array<'tNode> = "from"
