type rec sourceLocation = {
  componentName: string,
  file: string,
  line: int,
  column: int,
  componentProps: option<Dict.t<JSON.t>>,
  parent: option<sourceLocation>,
}

@module("./DOMElementToComponentSourceRuntime.mjs")
external resolveSourceLocationInServer: (
  sourceLocation,
  ~projectRoot: string,
) => promise<sourceLocation> = "resolveSourceLocationInServer"
