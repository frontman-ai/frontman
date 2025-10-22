open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleValue/parse_static)
*/
@scope("CSSStyleValue")
external parse: (~property: string, ~cssText: string) => cssStyleValue = "parse"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CSSStyleValue/parseAll_static)
*/
@scope("CSSStyleValue")
external parseAll: (~property: string, ~cssText: string) => array<cssStyleValue> = "parseAll"
