include DocumentFragment.Impl({type t = DomTypes.shadowRoot})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/getAnimations)
*/
@send
external getAnimations: DomTypes.shadowRoot => array<DomTypes.animation> = "getAnimations"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/setHTMLUnsafe)
*/
@send
external setHTMLUnsafe: (DomTypes.shadowRoot, string) => unit = "setHTMLUnsafe"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/getHTML)
*/
@send
external getHTML: (DomTypes.shadowRoot, ~options: DomTypes.getHTMLOptions=?) => string = "getHTML"
