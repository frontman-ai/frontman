type browser
type page
type locator
type route
@send external route: (page, string, route => Promise.t<unit>) => Promise.t<unit> = "route"
@send
external fulfill: (route, {"contentType": string, "body": string}) => Promise.t<unit> = "fulfill"
type launchOptions = {"headless": bool}
type pageOptions = {"colorScheme": [#dark | #light]}
type waitOptions = {"timeout": int}
@module("playwright") @scope("firefox")
external launchFirefox: launchOptions => Promise.t<browser> = "launch"
@send external newPage: (browser, pageOptions) => Promise.t<page> = "newPage"
@send external onPageError: (page, @as("pageerror") _, JsExn.t => unit) => unit = "on"
@send external goto: (page, string) => Promise.t<unit> = "goto"
@send external locator: (page, string) => locator = "locator"
@send external waitFor: (locator, waitOptions) => Promise.t<unit> = "waitFor"
@send external textContent: locator => Promise.t<Nullable.t<string>> = "textContent"
@send external close: browser => Promise.t<unit> = "close"
