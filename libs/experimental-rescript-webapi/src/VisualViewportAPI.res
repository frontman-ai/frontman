@@warning("-30")

open EventAPI

/**
[See VisualViewport on MDN](https://developer.mozilla.org/docs/Web/API/VisualViewport)
*/
type visualViewport = {
  ...eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VisualViewport/offsetLeft)
    */
  offsetLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VisualViewport/offsetTop)
    */
  offsetTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VisualViewport/pageLeft)
    */
  pageLeft: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VisualViewport/pageTop)
    */
  pageTop: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VisualViewport/width)
    */
  width: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VisualViewport/height)
    */
  height: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/VisualViewport/scale)
    */
  scale: float,
}
