%%raw("import '@radix-ui/themes/styles.css'")
%%raw("import './index.css'")

let defaultEndpoint = "ws://localhost:4000/socket"

// Get the script's own URL (not the page URL)
@val external importMetaUrl: string = "import.meta.url"

let getClientName = () => {
  let url = WebAPI.URL.make(~url=importMetaUrl)
  let params = url.searchParams
  if params->WebAPI.URLSearchParams.has(~name="clientName") {
    params->WebAPI.URLSearchParams.get("clientName")
  } else {
    "unknown"
  }
}

WebAPI.Global.document->WebAPI.Document.addEventListener(Custom("DOMContentLoaded"), _event => {
  let rootElement = WebAPI.Global.document->WebAPI.Document.querySelector("#root")
  Client__State.Actions.createNewTask()

  switch rootElement->Null.toOption {
  | Some(rootElement) =>
    let root = ReactDOM.Client.createRoot(rootElement->WebAPI.Element.asRescriptElement)
    let clientName = getClientName()
    root->ReactDOM.Client.Root.render(
      <React.StrictMode>
        <Client__FrontmanProvider.Provider clientName endpoint={defaultEndpoint}>
          <Client__App />
        </Client__FrontmanProvider.Provider>
      </React.StrictMode>,
    )
  | None => ()
  }
})
