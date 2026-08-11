type finderOptions = {
  root: WebAPI.DOMAPI.element,
  idName: (~name: string) => bool,
  className: (~name: string) => bool,
  tagName: (~name: string) => bool,
  attr: (~name: string, ~value: string) => bool,
  timeoutMs?: int,
  seedMinLength?: int,
  optimizedMinLength?: int,
  maxNumberOfPathChecks?: int,
}
@module("@medv/finder")
external finder: (~element: WebAPI.DOMAPI.element, ~options: finderOptions) => string = "finder"
