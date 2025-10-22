@@warning("-30")

/**
[See ViewTransition on MDN](https://developer.mozilla.org/docs/Web/API/ViewTransition)
*/
@editor.completeFrom(ViewTransition)
type viewTransition = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ViewTransition/updateCallbackDone)
    */
  updateCallbackDone: promise<unit>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ViewTransition/ready)
    */
  ready: promise<unit>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ViewTransition/finished)
    */
  finished: promise<unit>,
}

type viewTransitionUpdateCallback = promise<JSON.t>
