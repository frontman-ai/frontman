type t = UrlTypes.urlSearchParams = private {...UrlTypes.urlSearchParams}

@new
external make: unit => t = "URLSearchParams"

@new
external fromKeyValueArray: array<(string, string)> => t = "URLSearchParams"

@new
external fromDict: dict<string> => t = "URLSearchParams"

@new
external fromString: string => t = "URLSearchParams"

@send
external append: (t, ~name: string, ~value: string) => unit = "append"

@send
external delete: (t, ~name: string, ~value: string=?) => unit = "delete"

@send
external entries: t => Iterator.t<(string, string)> = "entries"

@send
external get: (t, string) => null<string> = "get"

@send
external getAll: (t, string) => array<string> = "getAll"

@send
external has: (t, ~name: string, ~value: string=?) => bool = "has"

@send
external keys: t => Iterator.t<string> = "keys"

@send
external set: (t, ~name: string, ~value: string) => unit = "set"

@send
external sort: t => unit = "sort"

@send
external toString: t => string = "toString"

@send
external values: t => Iterator.t<string> = "values"
