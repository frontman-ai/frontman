type root
@module("react-dom/client") external createRoot: WebAPI.DomTypes.element => root = "createRoot"
@send external render: (root, React.element) => unit = "render"
@send external unmount: root => unit = "unmount"
@module("react") external act: (unit => Promise.t<unit>) => Promise.t<unit> = "act"
type inputPrototype
type setter
type descriptor = {set: setter}
@val @scope("HTMLInputElement") external inputPrototype: inputPrototype = "prototype"
@val @scope("Object")
external descriptor: (inputPrototype, string) => descriptor = "getOwnPropertyDescriptor"
@send external callSetter: (setter, WebAPI.DomTypes.element, string) => unit = "call"

let fill = async (input, value) => {
  await act(async () => {
    descriptor(inputPrototype, "value").set->callSetter(input, value)
    input
    ->WebAPI.Element.dispatchEvent(
      WebAPI.Event.make(~type_="input", ~eventInitDict={bubbles: true}),
    )
    ->ignore
  })
}
