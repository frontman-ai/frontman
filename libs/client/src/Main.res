%%raw("import '@radix-ui/themes/styles.css'")
%%raw("import './index.css'")

FrontmanLogs.Logs.setLogLevel(
  if Client__Env.isDev {
    Debug
  } else {
    Error
  },
)
FrontmanLogs.Logs.addHandler(FrontmanLogs.Logs.Console.handler)
FrontmanLogs.Logs.addHandler(FrontmanAiFrontmanClient.FrontmanClient__Sentry__LogHandler.handler)

Client__Heap.init()

@val external importMetaUrl: string = "import.meta.url"

type clientConfig = {
  clientName: string,
  endpoint: string,
  tokenUrl: string,
  loginUrl: string,
  apiBaseUrl: string,
}

let getConfig = (): clientConfig => {
  let url = WebAPI.URL.make(~url=importMetaUrl)
  let params = url.searchParams
  let get = name =>
    if params->WebAPI.URLSearchParams.has(~name) {
      Some(params->WebAPI.URLSearchParams.get(name))
    } else {
      None
    }
  let host = switch get("host") {
  | Some(h) => h
  | None => JsError.throwWithMessage("host param is required")
  }
  {
    clientName: get("clientName")->Option.getOr("unknown"),
    endpoint: `wss://${host}/socket`,
    tokenUrl: `https://${host}/api/socket-token`,
    loginUrl: `https://${host}/users/log-in`,
    apiBaseUrl: `https://${host}`,
  }
}

WebAPI.Global.document->WebAPI.Document.addEventListener(Custom("DOMContentLoaded"), _event => {
  let rootElement = WebAPI.Global.document->WebAPI.Document.querySelector("#root")
  // Task is now created when session is established (in Connect action handler)
  // to ensure task ID matches sessionId for proper update routing

  switch rootElement->Null.toOption {
  | Some(rootElement) =>
    let root = ReactDOM.Client.createRoot(rootElement->WebAPI.Element.asRescriptElement)
    let config = getConfig()
    root->ReactDOM.Client.Root.render(
      <React.StrictMode>
        <Client__FrontmanProvider.Provider
          clientName={config.clientName}
          endpoint={config.endpoint}
          tokenUrl={config.tokenUrl}
          loginUrl={config.loginUrl}
        >
          <Client__App apiBaseUrl={config.apiBaseUrl} />
        </Client__FrontmanProvider.Provider>
      </React.StrictMode>,
    )
  | None => ()
  }
})
