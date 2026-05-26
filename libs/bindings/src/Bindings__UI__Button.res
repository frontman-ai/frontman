// UI Button component bindings
// Usage:
// <UI__Button variant=#primary size=#lg onClick={_ => Js.log("clicked")}>
//   {React.string("Click me")}
// </UI__Button>
//
// With asChild to render as a different element:
// <UI__Button asChild=true>
//   <a href="/home">{React.string("Go Home")}</a>
// </UI__Button>

type variant = [
  | #default
  | #destructive
  | #outline
  | #secondary
  | #ghost
  | #link
]

type size = [
  | #default
  | #sm
  | #lg
  | #icon
  | #"icon-sm"
  | #"icon-lg"
]

type buttonType = [#button | #submit | #reset]

module Button = {
  @module("@/components/ui/button") @react.component
  external make: (
    ~className: string=?,
    ~variant: variant=?,
    ~size: size=?,
    ~asChild: bool=?,
    ~type_: buttonType=?,
    ~disabled: bool=?,
    ~onClick: ReactEvent.Mouse.t => unit=?,
    ~onMouseEnter: ReactEvent.Mouse.t => unit=?,
    ~onMouseLeave: ReactEvent.Mouse.t => unit=?,
    ~style: {..}=?,
    ~children: React.element=?,
  ) => React.element = "Button"
}
