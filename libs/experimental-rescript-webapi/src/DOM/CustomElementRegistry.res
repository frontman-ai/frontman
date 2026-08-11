/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CustomElementRegistry/define)
*/
@send
external define: (
  DomTypes.customElementRegistry,
  ~name: string,
  ~constructor: DomTypes.htmlElement,
  ~options: DomTypes.elementDefinitionOptions=?,
) => unit = "define"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CustomElementRegistry/getName)
*/
@send
external getName: (DomTypes.customElementRegistry, DomTypes.customElementConstructor) => string =
  "getName"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CustomElementRegistry/whenDefined)
*/
@send
external whenDefined: (
  DomTypes.customElementRegistry,
  string,
) => promise<DomTypes.customElementConstructor> = "whenDefined"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CustomElementRegistry/upgrade)
*/
@send
external upgrade: (DomTypes.customElementRegistry, DomTypes.node) => unit = "upgrade"
