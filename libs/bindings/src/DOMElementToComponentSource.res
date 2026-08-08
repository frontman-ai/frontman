type rec sourceLocation = {
  componentName: string,
  file: string,
  line: int,
  column: int,
  componentProps: option<Dict.t<JSON.t>>,
  parent: option<sourceLocation>,
}

@module("dom-element-to-component-source/server")
external resolveSourceLocationInServer: sourceLocation => promise<sourceLocation> =
  "resolveSourceLocationInServer"
