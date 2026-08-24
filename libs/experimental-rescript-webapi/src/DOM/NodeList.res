/**
Returns the node with index index from the collection. The nodes are sorted in tree order.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeList/item)
*/
@send
external item: (DomTypes.nodeList<'tNode>, int) => 'tNode = "item"

@send
external forEach: (DomTypes.nodeList<'tNode>, 'tNode => unit) => unit = "forEach"

@scope("Array") @val
external toArray: DomTypes.nodeList<'tNode> => array<'tNode> = "from"
