// Radix UI Select bindings
// Usage:
// <RadixUI__Select.Root value={selected} onValueChange={v => setSelected(_ => v)}>
//   <RadixUI__Select.Trigger className="trigger-class">
//     <RadixUI__Select.Value placeholder="Select..." />
//     <RadixUI__Select.Icon><ChevronDownIcon /></RadixUI__Select.Icon>
//   </RadixUI__Select.Trigger>
//   <RadixUI__Select.Portal>
//     <RadixUI__Select.Content className="content-class">
//       <RadixUI__Select.Viewport>
//         <RadixUI__Select.Group>
//           <RadixUI__Select.Label>{React.string("Group Label")}</RadixUI__Select.Label>
//           <RadixUI__Select.Item value="item1">
//             <RadixUI__Select.ItemText>{React.string("Item 1")}</RadixUI__Select.ItemText>
//           </RadixUI__Select.Item>
//         </RadixUI__Select.Group>
//       </RadixUI__Select.Viewport>
//     </RadixUI__Select.Content>
//   </RadixUI__Select.Portal>
// </RadixUI__Select.Root>

type dir = [#ltr | #rtl]
type position = [#"item-aligned" | #popper]
type side = [#top | #right | #bottom | #left]
type align = [#start | #center | #end_]
type sticky = [#partial | #always]

module Root = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~defaultValue: string=?,
    ~value: string=?,
    ~onValueChange: string => unit=?,
    ~defaultOpen: bool=?,
    ~open_: bool=?,
    ~onOpenChange: bool => unit=?,
    ~dir: dir=?,
    ~name: string=?,
    ~disabled: bool=?,
    ~required: bool=?,
    ~children: React.element=?,
  ) => React.element = "Root"
}

module Trigger = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Trigger"
}

module Value = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~placeholder: React.element=?,
    ~className: string=?,
    ~style: {..}=?,
  ) => React.element = "Value"
}

module Icon = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Icon"
}

module Portal = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~container: Dom.element=?,
    ~children: React.element=?,
  ) => React.element = "Portal"
}

module Content = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~position: position=?,
    ~side: side=?,
    ~sideOffset: int=?,
    ~align: align=?,
    ~alignOffset: int=?,
    ~avoidCollisions: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Content"
}

module Viewport = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Viewport"
}

module Group = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Group"
}

module Label = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Label"
}

module Item = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~value: string,
    ~disabled: bool=?,
    ~textValue: string=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Item"
}

module ItemText = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "ItemText"
}

module ItemIndicator = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "ItemIndicator"
}

module ScrollUpButton = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "ScrollUpButton"
}

module ScrollDownButton = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "ScrollDownButton"
}

module Separator = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~style: {..}=?,
  ) => React.element = "Separator"
}
