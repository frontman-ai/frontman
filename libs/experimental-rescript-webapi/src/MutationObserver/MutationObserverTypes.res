/**
[See WebApiMutationObserver on MDN](https://developer.mozilla.org/docs/Web/API/MutationObserver)
*/
@editor.completeFrom(WebApiMutationObserver)
type mutationObserver

type mutationObserverInit = {
  mutable childList?: bool,
  mutable attributes?: bool,
  mutable characterData?: bool,
  mutable subtree?: bool,
  mutable attributeOldValue?: bool,
  mutable characterDataOldValue?: bool,
  mutable attributeFilter?: array<string>,
}

type mutationObserverCallback = (array<DOM.mutationRecord>, mutationObserver) => unit
