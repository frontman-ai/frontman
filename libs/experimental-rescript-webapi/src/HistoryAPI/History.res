open HistoryAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/History/go)
*/
@send
external go: (history, ~delta: int=?) => unit = "go"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/History/back)
*/
@send
external back: history => unit = "back"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/History/forward)
*/
@send
external forward: history => unit = "forward"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/History/pushState)
*/
@send
external pushState: (history, ~data: JSON.t, ~unused: string, ~url: string=?) => unit = "pushState"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/History/replaceState)
*/
@send
external replaceState: (history, ~data: JSON.t, ~unused: string, ~url: string=?) => unit =
  "replaceState"
