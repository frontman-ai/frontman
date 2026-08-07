@send
external item: (DomTypes.domTokenList, int) => string = "item"

@send
external contains: (DomTypes.domTokenList, string) => bool = "contains"

@send
external add: (DomTypes.domTokenList, string) => unit = "add"

@send
external remove: (DomTypes.domTokenList, string) => unit = "remove"

@send
external toggle: (DomTypes.domTokenList, ~token: string, ~force: bool=?) => bool = "toggle"

@send
external replace: (DomTypes.domTokenList, ~token: string, ~newToken: string) => bool = "replace"

@send
external supports: (DomTypes.domTokenList, string) => bool = "supports"
