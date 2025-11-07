// UI ButtonGroup component bindings
// Usage:
// <ButtonGroup orientation=#horizontal>
//   <Button variant=#primary>{React.string("First")}</Button>
//   <ButtonGroupSeparator />
//   <Button variant=#secondary>{React.string("Second")}</Button>
// </ButtonGroup>
//
// With ButtonGroupText:
// <ButtonGroup>
//   <ButtonGroupText>{React.string("Label")}</ButtonGroupText>
//   <Button>{React.string("Action")}</Button>
// </ButtonGroup>

type orientation = [#horizontal | #vertical]

module ButtonGroup = {
  @module("@/components/ui/button-group") @react.component
  external make: (
    ~className: string=?,
    ~orientation: orientation=?,
    ~children: React.element=?,
  ) => React.element = "ButtonGroup"
}

module ButtonGroupText = {
  @module("@/components/ui/button-group") @react.component
  external make: (
    ~className: string=?,
    ~asChild: bool=?,
    ~children: React.element=?,
  ) => React.element = "ButtonGroupText"
}

module ButtonGroupSeparator = {
  @module("@/components/ui/button-group") @react.component
  external make: (~className: string=?, ~orientation: orientation=?) => React.element =
    "ButtonGroupSeparator"
}
