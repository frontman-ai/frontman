type server
type request = {url: string}
type response
@module("node:http") external createServer: ((request, response) => unit) => server = "createServer"
@send external listen: (server, int, string, unit => unit) => unit = "listen"
type address = {port: int}
@send external address: server => address = "address"
@send external closeServer: (server, Nullable.t<JsExn.t> => unit) => unit = "close"
@send external setHeader: (response, string, string) => unit = "setHeader"
@send external endResponse: (response, string) => unit = "end"
@module("node:fs/promises")
external readFile: (string, @as("utf8") _) => Promise.t<string> = "readFile"
type buildConfig = {
  "configFile": bool,
  "build": {"lib": {"entry": string, "formats": array<string>}, "write": bool, "minify": bool},
  "define": Dict.t<string>,
}
type bundle = {output: array<{"type": string, "isEntry": option<bool>, "code": option<string>}>}
@module("vite") external build: buildConfig => Promise.t<array<bundle>> = "build"
type browser
type page
type locator
type launchOptions = {"headless": bool}
type pageOptions = {"colorScheme": string}
type waitOptions = {"timeout": int}
@module("playwright") @scope("firefox")
external launch: launchOptions => Promise.t<browser> = "launch"
@send external newPage: (browser, pageOptions) => Promise.t<page> = "newPage"
@send external onError: (page, @as("pageerror") _, JsExn.t => unit) => unit = "on"
@send external goto: (page, string) => Promise.t<unit> = "goto"
@send external locator: (page, string) => locator = "locator"
@send external waitFor: (locator, waitOptions) => Promise.t<unit> = "waitFor"
@send external textContent: locator => Promise.t<Nullable.t<string>> = "textContent"
@send external closeBrowser: browser => Promise.t<unit> = "close"
