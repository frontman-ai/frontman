open DOMAPI

/**
Returns the node with index index from the collection. The nodes are sorted in tree order.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeList/item)
*/
@send
external item: (nodeList, int) => node = "item"
