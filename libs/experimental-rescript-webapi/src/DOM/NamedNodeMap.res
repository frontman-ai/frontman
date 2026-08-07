@send
external item: (DomTypes.namedNodeMap, int) => DomTypes.attr = "item"

@send
external getNamedItem: (DomTypes.namedNodeMap, string) => DomTypes.attr = "getNamedItem"

@send
external getNamedItemNS: (
  DomTypes.namedNodeMap,
  ~namespace: string,
  ~localName: string,
) => DomTypes.attr = "getNamedItemNS"

@send
external setNamedItem: (DomTypes.namedNodeMap, DomTypes.attr) => DomTypes.attr = "setNamedItem"

@send
external setNamedItemNS: (DomTypes.namedNodeMap, DomTypes.attr) => DomTypes.attr = "setNamedItemNS"

@send
external removeNamedItem: (DomTypes.namedNodeMap, string) => DomTypes.attr = "removeNamedItem"

@send
external removeNamedItemNS: (
  DomTypes.namedNodeMap,
  ~namespace: string,
  ~localName: string,
) => DomTypes.attr = "removeNamedItemNS"
