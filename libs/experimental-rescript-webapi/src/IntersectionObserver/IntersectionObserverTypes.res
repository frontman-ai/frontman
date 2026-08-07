@@warning("-30")

@editor.completeFrom(IntersectionObserverRoot)
type root

@editor.completeFrom(WebApiIntersectionObserver)
type intersectionObserver = private {
  root: root,
  rootMargin: string,
  thresholds: array<float>,
}

type intersectionObserverEntry = {
  time: float,
  rootBounds: Null.t<DomTypes.domRectReadOnly>,
  boundingClientRect: DomTypes.domRectReadOnly,
  intersectionRect: DomTypes.domRectReadOnly,
  isIntersecting: bool,
  intersectionRatio: float,
  target: DomTypes.element,
}

type intersectionObserverInit = {
  mutable root?: root,
  mutable rootMargin?: string,
  mutable threshold?: array<float>,
}

type intersectionObserverCallback = (array<intersectionObserverEntry>, intersectionObserver) => unit
