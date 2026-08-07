@scope("CSSStyleValue")
external parse: (~property: string, ~cssText: string) => DomTypes.cssStyleValue = "parse"

@scope("CSSStyleValue")
external parseAll: (~property: string, ~cssText: string) => array<DomTypes.cssStyleValue> =
  "parseAll"
