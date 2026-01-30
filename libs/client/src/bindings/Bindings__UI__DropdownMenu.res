// UI DropdownMenu component bindings (wraps @radix-ui/react-dropdown-menu)
// Usage:
// <DropdownMenu.DropdownMenu>
//   <DropdownMenu.DropdownMenuTrigger asChild=true>
//     <button>{React.string("+3")}</button>
//   </DropdownMenu.DropdownMenuTrigger>
//   <DropdownMenu.DropdownMenuContent align="end" sideOffset=4>
//     <DropdownMenu.DropdownMenuLabel>{React.string("More tasks")}</DropdownMenu.DropdownMenuLabel>
//     <DropdownMenu.DropdownMenuSeparator />
//     <DropdownMenu.DropdownMenuItem onSelect={_ => handleSelect()}>
//       {React.string("Task title")}
//     </DropdownMenu.DropdownMenuItem>
//   </DropdownMenu.DropdownMenuContent>
// </DropdownMenu.DropdownMenu>

module DropdownMenu = {
  @module("@/components/ui/dropdown-menu") @react.component
  external make: (
    @as("open") ~open_: bool=?,
    ~defaultOpen: bool=?,
    ~onOpenChange: bool => unit=?,
    ~children: React.element=?,
  ) => React.element = "DropdownMenu"
}

module DropdownMenuTrigger = {
  @module("@/components/ui/dropdown-menu") @react.component
  external make: (
    ~className: string=?,
    ~asChild: bool=?,
    ~children: React.element=?,
  ) => React.element = "DropdownMenuTrigger"
}

module DropdownMenuContent = {
  @module("@/components/ui/dropdown-menu") @react.component
  external make: (
    ~className: string=?,
    ~align: string=?,
    ~sideOffset: int=?,
    ~children: React.element=?,
  ) => React.element = "DropdownMenuContent"
}

module DropdownMenuItem = {
  @module("@/components/ui/dropdown-menu") @react.component
  external make: (
    ~className: string=?,
    ~onSelect: ReactEvent.Mouse.t => unit=?,
    ~children: React.element=?,
  ) => React.element = "DropdownMenuItem"
}

module DropdownMenuSeparator = {
  @module("@/components/ui/dropdown-menu") @react.component
  external make: (~className: string=?) => React.element = "DropdownMenuSeparator"
}

module DropdownMenuLabel = {
  @module("@/components/ui/dropdown-menu") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "DropdownMenuLabel"
}
