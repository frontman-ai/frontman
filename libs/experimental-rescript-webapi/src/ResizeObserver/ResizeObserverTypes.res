@@warning("-30")

type resizeObserverBoxOptions =
  | @as("border-box") BorderBox
  | @as("content-box") ContentBox
  | @as("device-pixel-content-box") DevicePixelContentBox

type resizeObserverSize = {
  inlineSize: float,
  blockSize: float,
}

type resizeObserverEntry = {
  target: DomTypes.element,
  contentRect: DomTypes.domRectReadOnly,
  borderBoxSize: array<resizeObserverSize>,
  contentBoxSize: array<resizeObserverSize>,
  devicePixelContentBoxSize: array<resizeObserverSize>,
}

@editor.completeFrom(WebApiResizeObserver)
type resizeObserver = private {}

type resizeObserverOptions = {mutable box?: resizeObserverBoxOptions}

type resizeObserverCallback = array<resizeObserverEntry> => resizeObserver => unit
