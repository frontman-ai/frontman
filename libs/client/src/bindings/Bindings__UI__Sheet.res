// UI Sheet component bindings
// Usage:
// <Sheet open={isOpen} onOpenChange={setIsOpen}>
//   <SheetTrigger asChild={true}>
//     <Button>{React.string("Open Sheet")}</Button>
//   </SheetTrigger>
//   <SheetContent side=#right>
//     <SheetHeader>
//       <SheetTitle>{React.string("Title")}</SheetTitle>
//       <SheetDescription>{React.string("Description")}</SheetDescription>
//     </SheetHeader>
//     {React.string("Content goes here")}
//     <SheetFooter>
//       <Button>{React.string("Save")}</Button>
//     </SheetFooter>
//   </SheetContent>
// </Sheet>

type side = [#top | #right | #bottom | #left]

module Sheet = {
  @module("@/components/ui/sheet") @react.component
  external make: (
    ~className: string=?,
    ~\"open": bool=?,
    ~defaultOpen: bool=?,
    ~onOpenChange: bool => unit=?,
    ~modal: bool=?,
    ~children: React.element=?,
  ) => React.element = "Sheet"
}

module SheetTrigger = {
  @module("@/components/ui/sheet") @react.component
  external make: (
    ~className: string=?,
    ~asChild: bool=?,
    ~children: React.element=?,
  ) => React.element = "SheetTrigger"
}

module SheetClose = {
  @module("@/components/ui/sheet") @react.component
  external make: (
    ~className: string=?,
    ~asChild: bool=?,
    ~children: React.element=?,
  ) => React.element = "SheetClose"
}

module SheetContent = {
  @module("@/components/ui/sheet") @react.component
  external make: (
    ~className: string=?,
    ~side: side=?,
    ~children: React.element=?,
  ) => React.element = "SheetContent"
}

module SheetHeader = {
  @module("@/components/ui/sheet") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "SheetHeader"
}

module SheetFooter = {
  @module("@/components/ui/sheet") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "SheetFooter"
}

module SheetTitle = {
  @module("@/components/ui/sheet") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "SheetTitle"
}

module SheetDescription = {
  @module("@/components/ui/sheet") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "SheetDescription"
}
