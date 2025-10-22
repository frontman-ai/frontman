open DOMAPI

include DocumentFragment.Impl({type t = shadowRoot})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/getAnimations)
*/
@send
external getAnimations: shadowRoot => array<animation> = "getAnimations"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/setHTMLUnsafe)
*/
@send
external setHTMLUnsafe: (shadowRoot, string) => unit = "setHTMLUnsafe"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/ShadowRoot/getHTML)
*/
@send
external getHTML: (shadowRoot, ~options: getHTMLOptions=?) => string = "getHTML"
