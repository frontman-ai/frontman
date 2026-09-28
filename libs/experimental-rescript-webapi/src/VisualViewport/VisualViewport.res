type t = VisualViewportTypes.visualViewport = private {
  ...VisualViewportTypes.visualViewport,
}

include EventTarget.Impl({type t = t})
