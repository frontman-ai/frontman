type t = FetchTypes.headersInit

external fromDict: dict<string> => t = "%identity"

external fromHeaders: FetchTypes.headers => t = "%identity"

external fromKeyValueArray: array<(string, string)> => t = "%identity"
