// Bindings for the Web Storage API (localStorage)

@val @scope("localStorage")
external getItem: string => Nullable.t<string> = "getItem"

@val @scope("localStorage")
external setItem: (string, string) => unit = "setItem"

@val @scope("localStorage")
external removeItem: string => unit = "removeItem"

@val @scope("localStorage")
external key: int => Nullable.t<string> = "key"

@val @scope("localStorage")
external length: int = "length"
