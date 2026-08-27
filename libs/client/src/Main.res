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
external asReactElement: WebAPI.DomTypes.element => Dom.element = "%identity"

type clientConfig = {
  clientName: string,
  sentryDsn: option<string>,
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
      params->WebAPI.URLSearchParams.get(name)->Null.toOption
    } else {
      None
    }
  let host = switch get("host") {
  | Some(h) => h
  | None => JsError.throwWithMessage("host param is required")
  }
  {
    clientName: get("clientName")->Option.getOr("unknown"),
    sentryDsn: get("sentryDsn"),
    endpoint: `wss://${host}/socket`,
    tokenUrl: `https://${host}/api/socket-token`,
    loginUrl: `https://${host}/users/log-in`,
    apiBaseUrl: `https://${host}`,
  }
}

WebAPI.Window.current
->WebAPI.Window.document
->WebAPI.Document.addEventListener(Custom("DOMContentLoaded"), _event => {
  let rootElement =
    WebAPI.Window.current->WebAPI.Window.document->WebAPI.Document.querySelector("#root")

  switch rootElement->Null.toOption {
  | Some(rootElement) =>
    let root = ReactDOM.Client.createRoot(rootElement->asReactElement)
    let config = getConfig()
    config.sentryDsn->Option.forEach(dsn =>
      FrontmanAiFrontmanClient.FrontmanClient__Sentry.initialize(~dsn)
    )
    Client__State.Actions.fetchUserProfile(~apiBaseUrl=config.apiBaseUrl)
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
