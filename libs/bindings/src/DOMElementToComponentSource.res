// Bindings for dom-element-to-component-source server-side functions

// Source location type (used for both input and output)
@schema
type sourceLocation = {
  componentName: string,
  file: string,
  line: int,
  column: int,
}

// The actual JavaScript function returns a sourceLocation object directly,
// not wrapped in a result object
@module("dom-element-to-component-source/server")
external resolveSourceLocationInServer: sourceLocation => promise<sourceLocation> =
  "resolveSourceLocationInServer"
