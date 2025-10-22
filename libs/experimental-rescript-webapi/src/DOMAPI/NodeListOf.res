open DOMAPI

external asNodeList: nodeListOf<'tNode> => nodeList = "%identity"
/**
Returns the node with index index from the collection. The nodes are sorted in tree order.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NodeList/item)
*/
@send
external item: (nodeListOf<'tNode>, int) => node = "item"
