@@warning("-30")

@editor.completeFrom(ViewTransition)
type viewTransition = private {
  updateCallbackDone: promise<unit>,
  ready: promise<unit>,
  finished: promise<unit>,
}

type viewTransitionUpdateCallback = promise<JSON.t>
