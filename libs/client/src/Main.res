%%raw("import '@radix-ui/themes/styles.css'")
%%raw("import './index.css'")

WebAPI.Global.document->WebAPI.Document.addEventListener(Custom("DOMContentLoaded"), _event => {
  let rootElement = WebAPI.Global.document->WebAPI.Document.querySelector("#root")
  Client__State.Actions.createNewTask()
  switch rootElement->Null.toOption {
  | Some(rootElement) =>
    let root = ReactDOM.Client.createRoot(rootElement->WebAPI.Element.asRescriptElement)
    root->ReactDOM.Client.Root.render(
      <React.StrictMode>
        <Client__App />
      </React.StrictMode>,
    )
  | None => ()
  }
})
