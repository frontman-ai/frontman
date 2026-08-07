@new
external make: unit => FetchTypes.headers = "Headers"

@new
external fromDict: dict<string> => FetchTypes.headers = "Headers"

@new
external fromHeaders: FetchTypes.headers => FetchTypes.headers = "Headers"

@new
external fromKeyValueArray: array<(string, string)> => FetchTypes.headers = "Headers"

@send
external append: (FetchTypes.headers, ~name: string, ~value: string) => unit = "append"

@send
external delete: (FetchTypes.headers, string) => unit = "delete"

@send
external get: (FetchTypes.headers, string) => null<string> = "get"

@send
external getSetCookie: FetchTypes.headers => array<string> = "getSetCookie"

@send
external has: (FetchTypes.headers, string) => bool = "has"

@send
external set: (FetchTypes.headers, ~name: string, ~value: string) => unit = "set"
