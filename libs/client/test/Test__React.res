module Dom = FrontmanBindings.Bindings__WebAPI
let createRoot = element => ReactDOM.Client.createRoot(element->Dom.elementToReact)
let render = ReactDOM.Client.Root.render
let unmount = root => ReactDOM.Client.Root.unmount(root, ())
let act = React.act

let fill = async (element, value) => {
  let input = element->Dom.inputElementFromElement->Option.getOrThrow
  await React.act(async () => {
    FrontmanBindings.Bindings__HTMLInputElement.setNativeValue(input, value)
    input
    ->WebAPI.HTMLInputElement.dispatchEvent(
      WebAPI.Event.make(~type_="input", ~eventInitDict={bubbles: true}),
    )
    ->ignore
  })
}
