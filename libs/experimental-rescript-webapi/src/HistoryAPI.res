@@warning("-30")

type scrollRestoration =
  | @as("auto") Auto
  | @as("manual") Manual

/**
Allows manipulation of the browser session history, that is the pages visited in the tab or frame that the current page is loaded in.
[See History on MDN](https://developer.mozilla.org/docs/Web/API/History)
*/
@editor.completeFrom(History)
type history = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/History/length)
    */
  length: int,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/History/scrollRestoration)
    */
  mutable scrollRestoration: scrollRestoration,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/History/state)
    */
  state: JSON.t,
}
