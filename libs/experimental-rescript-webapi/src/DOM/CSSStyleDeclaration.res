/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleDeclaration/item)
*/
@send
external item: (DomTypes.cssStyleDeclaration, int) => string = "item"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleDeclaration/getPropertyValue)
*/
@send
external getPropertyValue: (DomTypes.cssStyleDeclaration, string) => string = "getPropertyValue"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleDeclaration/getPropertyPriority)
*/
@send
external getPropertyPriority: (DomTypes.cssStyleDeclaration, string) => string =
  "getPropertyPriority"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleDeclaration/setProperty)
*/
@send
external setProperty: (
  DomTypes.cssStyleDeclaration,
  ~property: string,
  ~value: string,
  ~priority: string=?,
) => unit = "setProperty"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleDeclaration/removeProperty)
*/
@send
external removeProperty: (DomTypes.cssStyleDeclaration, string) => string = "removeProperty"
