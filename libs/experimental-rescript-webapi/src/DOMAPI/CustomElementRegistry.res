open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CustomElementRegistry/define)
*/
@send
external define: (
  customElementRegistry,
  ~name: string,
  ~constructor: customElementConstructor,
  ~options: elementDefinitionOptions=?,
) => unit = "define"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CustomElementRegistry/getName)
*/
@send
external getName: (customElementRegistry, customElementConstructor) => string = "getName"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CustomElementRegistry/whenDefined)
*/
@send
external whenDefined: (customElementRegistry, string) => promise<customElementConstructor> =
  "whenDefined"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CustomElementRegistry/upgrade)
*/
@send
external upgrade: (customElementRegistry, node) => unit = "upgrade"
