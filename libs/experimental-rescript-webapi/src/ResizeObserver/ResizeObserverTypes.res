@@warning("-30")

type resizeObserverBoxOptions =
  | @as("border-box") BorderBox
  | @as("content-box") ContentBox
  | @as("device-pixel-content-box") DevicePixelContentBox

/**
[See ResizeObserverSize on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserverSize)
*/
type resizeObserverSize = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserverSize/inlineSize)
    */
  inlineSize: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserverSize/blockSize)
    */
  blockSize: float,
}

/**
[See ResizeObserverEntry on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserverEntry)
*/
type resizeObserverEntry = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserverEntry/target)
    */
  target: DomTypes.element,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserverEntry/contentRect)
    */
  contentRect: DomTypes.domRectReadOnly,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserverEntry/borderBoxSize)
    */
  borderBoxSize: array<resizeObserverSize>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserverEntry/contentBoxSize)
    */
  contentBoxSize: array<resizeObserverSize>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserverEntry/devicePixelContentBoxSize)
    */
  devicePixelContentBoxSize: array<resizeObserverSize>,
}

/**
[See WebApiResizeObserver on MDN](https://developer.mozilla.org/docs/Web/API/ResizeObserver)
*/
@editor.completeFrom(WebApiResizeObserver)
type resizeObserver = private {}

type resizeObserverOptions = {mutable box?: resizeObserverBoxOptions}

type resizeObserverCallback = array<resizeObserverEntry> => resizeObserver => unit
