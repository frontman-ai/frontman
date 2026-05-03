// UI Dialog component bindings
// Usage:
// <UI__Dialog open={isOpen} onOpenChange={setIsOpen}>
//   <UI__DialogContent>
//     <UI__DialogTitle>{React.string("Title")}</UI__DialogTitle>
//     <UI__DialogDescription>
//       {React.string("Description")}
//     </UI__DialogDescription>
//   </UI__DialogContent>
// </UI__Dialog>

module Dialog = {
  @module("@/components/ui/dialog") @react.component
  external make: (
    @as("open") ~open_: bool=?,
    ~defaultOpen: bool=?,
    ~onOpenChange: bool => unit=?,
    ~children: React.element=?,
  ) => React.element = "Dialog"
}

module DialogClose = {
  @module("@/components/ui/dialog") @react.component
  external make: (
    ~className: string=?,
    ~asChild: bool=?,
    ~onClick: ReactEvent.Mouse.t => unit=?,
    ~disabled: bool=?,
    ~children: React.element=?,
  ) => React.element = "DialogClose"
}

module DialogContent = {
  @module("@/components/ui/dialog") @react.component
  external make: (
    ~className: string=?,
    ~showCloseButton: bool=?,
    ~onEscapeKeyDown: ReactEvent.Keyboard.t => unit=?,
    ~onPointerDownOutside: {..} => unit=?,
    ~children: React.element=?,
  ) => React.element = "DialogContent"
}

module DialogTitle = {
  @module("@/components/ui/dialog") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element = "DialogTitle"
}

module DialogDescription = {
  @module("@/components/ui/dialog") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element =
    "DialogDescription"
}
