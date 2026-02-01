// Type definitions for ChatMessages and related components

module SourceLocation = {
  type rec t = {
    componentName: option<string>,
    tagName: string,
    file: string,
    line: int,
    column: int,
    parent: option<t>,
    componentProps: option<Dict.t<JSON.t>>,
  }
}
