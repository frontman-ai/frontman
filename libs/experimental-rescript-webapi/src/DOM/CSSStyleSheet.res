@new
external make: (~options: DomTypes.cssStyleSheetInit=?) => DomTypes.cssStyleSheet = "CSSStyleSheet"

external asStyleSheet: DomTypes.cssStyleSheet => DomTypes.styleSheet = "%identity"
@send
external insertRule: (DomTypes.cssStyleSheet, ~rule: string, ~index: int=?) => int = "insertRule"

@send
external deleteRule: (DomTypes.cssStyleSheet, int) => unit = "deleteRule"

@send
external replace: (DomTypes.cssStyleSheet, string) => promise<DomTypes.cssStyleSheet> = "replace"

@send
external replaceSync: (DomTypes.cssStyleSheet, string) => unit = "replaceSync"
