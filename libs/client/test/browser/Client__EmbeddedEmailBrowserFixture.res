open WebAPI

@module("react-dom/client")
external createRoot: DomTypes.element => ReactDOM.Client.Root.t = "createRoot"

module Fixture = {
  @react.component
  let make = () => {
    let (status, setStatus) = React.useState(() => "pending")

    <button
      id="start-email-authorization"
      title=status
      onClick={_ => {
        setStatus(_ => "pending")
        Client__EmbeddedAuthPopup.start(
          ~loginUrl="https://localhost:4002/users/log-in",
          ~onSuccess=() => setStatus(_ => "complete"),
          ~onError=_ => setStatus(_ => "failed"),
        )->ignore
      }}>
      {React.string("Connect with email")}
    </button>
  }
}

let container = DomGlobal.document->Document.createElement("div")
DomGlobal.document.body->HTMLElement.appendChild(container->Element.asNode)->ignore
createRoot(container)->ReactDOM.Client.Root.render(<Fixture />)
