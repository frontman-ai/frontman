// UI Tooltip component bindings (wraps @radix-ui/react-tooltip)
// Usage:
// <Tooltip.Tooltip>
//   <Tooltip.TooltipTrigger>
//     <button>{React.string("Hover me")}</button>
//   </Tooltip.TooltipTrigger>
//   <Tooltip.TooltipContent sideOffset=4>
//     {React.string("Tooltip text")}
//   </Tooltip.TooltipContent>
// </Tooltip.Tooltip>

module Tooltip = {
  @module("@/components/ui/tooltip") @react.component
  external make: (~children: React.element=?) => React.element = "Tooltip"
}

module TooltipTrigger = {
  @module("@/components/ui/tooltip") @react.component
  external make: (
    ~className: string=?,
    ~asChild: bool=?,
    ~children: React.element=?,
  ) => React.element = "TooltipTrigger"
}

module TooltipContent = {
  @module("@/components/ui/tooltip") @react.component
  external make: (
    ~className: string=?,
    ~side: string=?,
    ~align: string=?,
    ~sideOffset: int=?,
    ~children: React.element=?,
  ) => React.element = "TooltipContent"
}
