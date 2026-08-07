type t = DOM.domStringList

@send
external item: (t, int) => string = "item"

@send
external contains: (t, string) => bool = "contains"
