@send
external add: (DomTypes.htmlOptionsCollection, ~element: unknown, ~before: unknown=?) => unit =
  "add"

@send
external remove: (DomTypes.htmlOptionsCollection, int) => unit = "remove"
