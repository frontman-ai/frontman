/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/item)
*/
@send
external item: (DomTypes.namedNodeMap, int) => DomTypes.attr = "item"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/getNamedItem)
*/
@send
external getNamedItem: (DomTypes.namedNodeMap, string) => DomTypes.attr = "getNamedItem"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/getNamedItemNS)
*/
@send
external getNamedItemNS: (
  DomTypes.namedNodeMap,
  ~namespace: string,
  ~localName: string,
) => DomTypes.attr = "getNamedItemNS"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/setNamedItem)
*/
@send
external setNamedItem: (DomTypes.namedNodeMap, DomTypes.attr) => DomTypes.attr = "setNamedItem"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/setNamedItemNS)
*/
@send
external setNamedItemNS: (DomTypes.namedNodeMap, DomTypes.attr) => DomTypes.attr = "setNamedItemNS"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/removeNamedItem)
*/
@send
external removeNamedItem: (DomTypes.namedNodeMap, string) => DomTypes.attr = "removeNamedItem"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/NamedNodeMap/removeNamedItemNS)
*/
@send
external removeNamedItemNS: (
  DomTypes.namedNodeMap,
  ~namespace: string,
  ~localName: string,
) => DomTypes.attr = "removeNamedItemNS"
