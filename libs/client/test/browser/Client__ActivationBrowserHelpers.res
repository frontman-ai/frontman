open WebAPI
module Reducer = Client__State__StateReducer
module Billing = Client__Billing

@module("../../dist/index.css?inline") external compiledCss: string = "default"
type page
type locator
type userEvent
type screenshotOptions = {@live path: string}
type locatorOptions = {@live name: string}
@module("vitest/browser") external page: page = "page"
@module("vitest/browser") external userEvent: userEvent = "userEvent"
@send external viewport: (page, int, int) => promise<unit> = "viewport"
@send external screenshot: (page, screenshotOptions) => promise<string> = "screenshot"
@send external getByRole: (page, string, locatorOptions) => locator = "getByRole"
@send external click: locator => promise<unit> = "click"
@send external fill: (locator, string) => promise<unit> = "fill"
@send external keyboard: (userEvent, string) => promise<unit> = "keyboard"
@module("vitest") @scope("vi") external waitFor: (unit => unit) => promise<unit> = "waitFor"
type spy<'a>
@module("vitest") @scope("vi") external spyOn: (WebAPI.Window.t, string) => spy<'a> = "spyOn"
@send external mockImplementation: (spy<'a>, 'a) => unit = "mockImplementation"
@module("vitest") @scope("vi") external restoreAllMocks: unit => unit = "restoreAllMocks"
@obj
external makeBillingTab: (
  ~closed: bool,
  ~close: unit => unit,
  ~location: {"assign": string => unit},
) => WebAPI.Window.t = ""

let original = StateStore.getState(Client__State__Store.store)
let root = ref(None)
let container = ref(None)
let query = selector => DomGlobal.document->Document.querySelector(selector)->Null.toOption
let force = state =>
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(Client__State__Store.store, state)
let loaded = (access, eligible) =>
  S.parseOrThrow(
    JSON.parseOrThrow(
      `{"status":"${access ? "trialing" : "none"}","access_allowed":${Bool.toString(
          access,
        )},"has_billing_customer":false,"trial_eligible":${Bool.toString(
          eligible,
        )},"trial_days":14,"interval":"monthly","current_period_end":null,"trial_end":null,"cancel_at":null,"canceled_at":null}`,
    ),
    ~to=Billing.statusSchema,
  )

@module("react-dom/client")
external createRoot: DomTypes.element => ReactDOM.Client.Root.t = "createRoot"

let render = element => {
  let el = DomGlobal.document->Document.createElement("div")
  DomGlobal.document.body->HTMLElement.appendChild(el->Element.asNode)->ignore
  container := Some(el)
  let mounted = createRoot(el)
  root := Some(mounted)
  mounted->ReactDOM.Client.Root.render(
    <>
      <style> {React.string(compiledCss)} </style>
      {element}
    </>,
  )
}

let setup = () => {
  Client__ActivationTestHelpers.setup()
  force({
    ...Reducer.defaultState,
    connection: Client__ConnectionTestHelpers.ready(),
    billingStatus: Loaded(loaded(false, true)),
  })
}
let cleanup = () => {
  root.contents->Option.forEach(root => root->ReactDOM.Client.Root.unmount())
  container.contents->Option.forEach(Element.remove)
  root := None
  force(original)
  restoreAllMocks()
  Client__EmbeddedAuth.clearToken()
}
