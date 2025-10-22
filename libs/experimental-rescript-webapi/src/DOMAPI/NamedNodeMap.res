open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/item)
*/
@send
external item: (namedNodeMap, int) => attr = "item"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/getNamedItem)
*/
@send
external getNamedItem: (namedNodeMap, string) => attr = "getNamedItem"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/getNamedItemNS)
*/
@send
external getNamedItemNS: (namedNodeMap, ~namespace: string, ~localName: string) => attr =
  "getNamedItemNS"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/setNamedItem)
*/
@send
external setNamedItem: (namedNodeMap, attr) => attr = "setNamedItem"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/setNamedItemNS)
*/
@send
external setNamedItemNS: (namedNodeMap, attr) => attr = "setNamedItemNS"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/removeNamedItem)
*/
@send
external removeNamedItem: (namedNodeMap, string) => attr = "removeNamedItem"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/removeNamedItemNS)
*/
@send
external removeNamedItemNS: (namedNodeMap, ~namespace: string, ~localName: string) => attr =
  "removeNamedItemNS"
