type t = FetchTypes.headersInit

/**
 [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_headers)
 */
external fromDict: dict<string> => t = "%identity"

/**
 [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_headers)
 */
external fromHeaders: FetchTypes.headers => t = "%identity"

/**
 [Read more on MDN](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch#setting_headers)
 */
external fromKeyValueArray: array<(string, string)> => t = "%identity"
