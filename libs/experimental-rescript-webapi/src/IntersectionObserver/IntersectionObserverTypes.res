@@warning("-30")

@editor.completeFrom(IntersectionObserverRoot)
type root

/**
provides a way to asynchronously observe changes in the intersection of a target element with an ancestor element or with a top-level document's viewport.
[See WebApiIntersectionObserver on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver)
*/
@editor.completeFrom(WebApiIntersectionObserver)
type intersectionObserver = private {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/root)
    */
  root: root,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/rootMargin)
    */
  rootMargin: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserver/thresholds)
    */
  thresholds: array<float>,
}

/**
This Intersection Observer API interface describes the intersection between the target element and its root container at a specific moment of transition.
[See IntersectionObserverEntry on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserverEntry)
*/
type intersectionObserverEntry = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserverEntry/time)
    */
  time: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserverEntry/rootBounds)
    */
  rootBounds: Null.t<DomTypes.domRectReadOnly>,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserverEntry/boundingClientRect)
    */
  boundingClientRect: DomTypes.domRectReadOnly,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserverEntry/intersectionRect)
    */
  intersectionRect: DomTypes.domRectReadOnly,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserverEntry/isIntersecting)
    */
  isIntersecting: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserverEntry/intersectionRatio)
    */
  intersectionRatio: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/IntersectionObserverEntry/target)
    */
  target: DomTypes.element,
}

type intersectionObserverInit = {
  mutable root?: root,
  mutable rootMargin?: string,
  mutable threshold?: array<float>,
}

type intersectionObserverCallback = (array<intersectionObserverEntry>, intersectionObserver) => unit
