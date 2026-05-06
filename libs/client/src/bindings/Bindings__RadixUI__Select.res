// Radix UI Select bindings
type position = [#"item-aligned" | #popper]

module Root = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~value: string=?,
    ~onValueChange: string => unit=?,
    ~children: React.element=?,
  ) => React.element = "Root"
}

module Trigger = {
  @module("@radix-ui/react-select") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element = "Trigger"
}

module Icon = {
  @module("@radix-ui/react-select") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element = "Icon"
}

module Portal = {
  @module("@radix-ui/react-select") @react.component
  external make: (~children: React.element=?) => React.element = "Portal"
}

module Content = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~position: position=?,
    ~sideOffset: int=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "Content"
}

module Viewport = {
  @module("@radix-ui/react-select") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element = "Viewport"
}

module Group = {
  @module("@radix-ui/react-select") @react.component
  external make: (~children: React.element=?) => React.element = "Group"
}

module Label = {
  @module("@radix-ui/react-select") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element = "Label"
}

module Item = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~value: string,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "Item"
}

module ItemText = {
  @module("@radix-ui/react-select") @react.component
  external make: (~children: React.element=?) => React.element = "ItemText"
}
