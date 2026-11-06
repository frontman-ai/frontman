type browser
type page
type locator
type launcher
type route
type request
type response
type context
type webSocketRoute
type launchOptions = {@live headless: bool, @live args?: array<string>}
type pageOptions = {@live serviceWorkers: string, @live storageState?: string}
type waitOptions = {@live state: string}
type screenshotOptions = {@live path: string, @live fullPage: bool}

@module("playwright") external chromium: launcher = "chromium"
@send external launch: (launcher, launchOptions) => promise<browser> = "launch"
@send external newPage: (browser, ~options: pageOptions=?) => promise<page> = "newPage"
@send external close: browser => promise<unit> = "close"
@send external goto: (page, string) => promise<unit> = "goto"
@send external gotoResponse: (page, string) => promise<response> = "goto"
@send external responseStatus: response => int = "status"
@send external locator: (page, string) => locator = "locator"
@send external count: locator => promise<int> = "count"
@send external textContent: locator => promise<string> = "textContent"
@send external click: locator => promise<unit> = "click"
@send external fill: (locator, string) => promise<unit> = "fill"
@send external pageUrl: page => string = "url"
@send external route: (page, string, route => promise<unit>) => promise<unit> = "route"
@send external request: route => request = "request"
@send external requestUrl: request => string = "url"
@send external abort: route => promise<unit> = "abort"
@send external continueRequest: route => promise<unit> = "continue"
@send external screenshot: (page, screenshotOptions) => promise<unit> = "screenshot"
@send external waitFor: (locator, ~options: waitOptions=?) => promise<unit> = "waitFor"
@send external isVisible: locator => promise<bool> = "isVisible"
@send external reload: page => promise<unit> = "reload"
@send external waitForResponse: (page, string) => promise<response> = "waitForResponse"
@send external responseJson: response => promise<JSON.t> = "json"
@send external context: page => context = "context"
@send external clearCookies: context => promise<unit> = "clearCookies"
@send external getAttribute: (locator, string) => promise<Null.t<string>> = "getAttribute"
@send
external routeWebSocket: (page, string, webSocketRoute => unit) => promise<unit> = "routeWebSocket"
@send external socketUrl: webSocketRoute => string = "url"
@send external connectToServer: webSocketRoute => unit = "connectToServer"
@send external closeSocket: webSocketRoute => unit = "close"
