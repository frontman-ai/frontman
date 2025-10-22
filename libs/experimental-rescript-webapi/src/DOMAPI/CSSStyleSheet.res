open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleSheet)
*/
@new
external make: (~options: cssStyleSheetInit=?) => cssStyleSheet = "CSSStyleSheet"

external asStyleSheet: cssStyleSheet => styleSheet = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleSheet/insertRule)
*/
@send
external insertRule: (cssStyleSheet, ~rule: string, ~index: int=?) => int = "insertRule"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleSheet/deleteRule)
*/
@send
external deleteRule: (cssStyleSheet, int) => unit = "deleteRule"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleSheet/replace)
*/
@send
external replace: (cssStyleSheet, string) => promise<cssStyleSheet> = "replace"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleSheet/replaceSync)
*/
@send
external replaceSync: (cssStyleSheet, string) => unit = "replaceSync"
