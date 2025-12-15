// Frontman Astro Integration

module Bindings = FrontmanAstro__AstroBindings

// SVG icon for the toolbar
let icon = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="3"/></svg>`

// Get the path to the toolbar app entrypoint
// Uses import.meta.url to resolve relative to this file
@val @scope(("import", "meta"))
external importMetaUrl: string = "url"

// Helper to create URL and get pathname
let getToolbarAppPath = () => {
  let url = WebAPI.URL.make(~url="./FrontmanAstro__ToolbarApp.res.mjs", ~base=importMetaUrl)
  url.pathname
}

// Create the Astro integration
let make = (): Bindings.astroIntegration => {
  name: "frontman",
  hooks: {
    configSetup: ?Some(ctx => {
      // Only add dev toolbar app in dev mode
      if ctx.command == #dev {
        ctx.addDevToolbarApp({
          id: "frontman:toolbar",
          name: "Frontman",
          icon,
          entrypoint: getToolbarAppPath(),
        })
      }
    }),
  },
}
