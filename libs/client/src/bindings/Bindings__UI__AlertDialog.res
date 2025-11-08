// UI AlertDialog component bindings
// Usage:
// <UI__AlertDialog open={isOpen} onOpenChange={setIsOpen}>
//   <UI__AlertDialogTrigger asChild=true>
//     <UI__Button variant=#destructive>{React.string("Delete")}</UI__Button>
//   </UI__AlertDialogTrigger>
//   <UI__AlertDialogContent>
//     <UI__AlertDialogHeader>
//       <UI__AlertDialogTitle>{React.string("Are you sure?")}</UI__AlertDialogTitle>
//       <UI__AlertDialogDescription>
//         {React.string("This action cannot be undone.")}
//       </UI__AlertDialogDescription>
//     </UI__AlertDialogHeader>
//     <UI__AlertDialogFooter>
//       <UI__AlertDialogCancel>{React.string("Cancel")}</UI__AlertDialogCancel>
//       <UI__AlertDialogAction onClick={handleDelete}>
//         {React.string("Continue")}
//       </UI__AlertDialogAction>
//     </UI__AlertDialogFooter>
//   </UI__AlertDialogContent>
// </UI__AlertDialog>

module AlertDialog = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (
    @as("open") ~open_: bool=?,
    ~defaultOpen: bool=?,
    ~onOpenChange: bool => unit=?,
    ~children: React.element=?,
  ) => React.element = "AlertDialog"
}

module AlertDialogTrigger = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (
    ~className: string=?,
    ~asChild: bool=?,
    ~onClick: ReactEvent.Mouse.t => unit=?,
    ~disabled: bool=?,
    ~children: React.element=?,
  ) => React.element = "AlertDialogTrigger"
}

module AlertDialogPortal = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element =
    "AlertDialogPortal"
}

module AlertDialogOverlay = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element =
    "AlertDialogOverlay"
}

module AlertDialogContent = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (
    ~className: string=?,
    ~onEscapeKeyDown: ReactEvent.Keyboard.t => unit=?,
    ~onPointerDownOutside: {..} => unit=?,
    ~children: React.element=?,
  ) => React.element = "AlertDialogContent"
}

module AlertDialogHeader = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element =
    "AlertDialogHeader"
}

module AlertDialogFooter = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element =
    "AlertDialogFooter"
}

module AlertDialogTitle = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element =
    "AlertDialogTitle"
}

module AlertDialogDescription = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (~className: string=?, ~children: React.element=?) => React.element =
    "AlertDialogDescription"
}

module AlertDialogAction = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (
    ~className: string=?,
    ~onClick: ReactEvent.Mouse.t => unit=?,
    ~disabled: bool=?,
    ~children: React.element=?,
  ) => React.element = "AlertDialogAction"
}

module AlertDialogCancel = {
  @module("@/components/ui/alert-dialog") @react.component
  external make: (
    ~className: string=?,
    ~onClick: ReactEvent.Mouse.t => unit=?,
    ~disabled: bool=?,
    ~children: React.element=?,
  ) => React.element = "AlertDialogCancel"
}
