open Bindings__DomTestingLibrary

module FireEvent = {
  include FireEvent
}

type renderResult = {
  container: option<WebAPI.DOMAPI.element>,
  baseElement: option<WebAPI.DOMAPI.element>,
  debug: unit => unit,
  rerender: React.element => unit,
  unmount: unit => unit,
}

type queries
type renderOptions = {
  "container": Js.undefined<WebAPI.DOMAPI.element>,
  "baseElement": Js.undefined<WebAPI.DOMAPI.element>,
  "hydrate": Js.undefined<bool>,
  "wrapper": Js.undefined<WebAPI.DOMAPI.element>,
  "queries": Js.undefined<queries>,
}

@module("@testing-library/react")
external cleanup: unit => unit = "cleanup"

@module("@testing-library/react")
external actPromise: (unit => unit) => promise<unit> = "act"

@module("@testing-library/react")
external actPromise2: (unit => promise<unit>) => promise<unit> = "act"

@module("@testing-library/react")
external _render: (React.element, renderOptions) => renderResult = "render"

@module("@testing-library/react")
external logDOM: WebAPI.DOMAPI.element => unit = "logDOM"

@module("@testing-library/react")
external prettyDOM: (WebAPI.DOMAPI.element, ~maxLength: int=?) => string = "prettyDOM"
let prettyDOMLimitless = (element: WebAPI.DOMAPI.element) =>
  prettyDOM(element, ~maxLength=Int.Constants.maxValue)

@get external container: renderResult => WebAPI.DOMAPI.element = "container"

@get external baseElement: renderResult => WebAPI.DOMAPI.element = "baseElement"

@send
external _debug: (Js.undefined<WebAPI.DOMAPI.element>, Js.undefined<int>) => unit = "debug"

external _unmount: unit => unit = "unmount"

external asFragment: unit => WebAPI.DOMAPI.element = "asFragment"

// ByLabelText
@send
external _getByLabelText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByLabelTextQuery.options>,
) => WebAPI.DOMAPI.element = "getByLabelText"

let getByLabelText = (~matcher, ~options=?, result) =>
  _getByLabelText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _getAllByLabelText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByLabelTextQuery.options>,
) => array<WebAPI.DOMAPI.element> = "getAllByLabelText"

let getAllByLabelText = (~matcher, ~options=?, result) =>
  _getAllByLabelText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryByLabelText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByLabelTextQuery.options>,
) => Js.null<WebAPI.DOMAPI.element> = "queryByLabelText"

let queryByLabelText = (~matcher, ~options=?, result) =>
  _queryByLabelText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryAllByLabelText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByLabelTextQuery.options>,
) => array<WebAPI.DOMAPI.element> = "queryAllByLabelText"

let queryAllByLabelText = (~matcher, ~options=?, result) =>
  _queryAllByLabelText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findByLabelText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByLabelTextQuery.options>,
) => promise<WebAPI.DOMAPI.element> = "findByLabelText"

let findByLabelText = (~matcher, ~options=?, result) =>
  _findByLabelText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findAllByLabelText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByLabelTextQuery.options>,
) => promise<array<WebAPI.DOMAPI.element>> = "findAllByLabelText"

let findAllByLabelText = (~matcher, ~options=?, result) =>
  _findAllByLabelText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

// ByPlaceholderText
@send
external _getByPlaceholderText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByPlaceholderTextQuery.options>,
) => WebAPI.DOMAPI.element = "getByPlaceholderText"

let getByPlaceholderText = (~matcher, ~options=?, result) =>
  _getByPlaceholderText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _getAllByPlaceholderText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByPlaceholderTextQuery.options>,
) => array<WebAPI.DOMAPI.element> = "getAllByPlaceholderText"

let getAllByPlaceholderText = (~matcher, ~options=?, result) =>
  _getAllByPlaceholderText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryByPlaceholderText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByPlaceholderTextQuery.options>,
) => Js.null<WebAPI.DOMAPI.element> = "queryByPlaceholderText"

let queryByPlaceholderText = (~matcher, ~options=?, result) =>
  _queryByPlaceholderText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryAllByPlaceholderText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByPlaceholderTextQuery.options>,
) => array<WebAPI.DOMAPI.element> = "queryAllByPlaceholderText"

let queryAllByPlaceholderText = (~matcher, ~options=?, result) =>
  _queryAllByPlaceholderText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findByPlaceholderText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByPlaceholderTextQuery.options>,
) => promise<WebAPI.DOMAPI.element> = "findByPlaceholderText"

let findByPlaceholderText = (~matcher, ~options=?, result) =>
  _findByPlaceholderText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findAllByPlaceholderText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByPlaceholderTextQuery.options>,
) => promise<array<WebAPI.DOMAPI.element>> = "findAllByPlaceholderText"

let findAllByPlaceholderText = (~matcher, ~options=?, result) =>
  _findAllByPlaceholderText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

// ByText
@send
external _getByText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTextQuery.options>,
) => WebAPI.DOMAPI.element = "getByText"

let getByText = (~matcher, ~options=?, result) =>
  _getByText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _getAllByText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTextQuery.options>,
) => array<WebAPI.DOMAPI.element> = "getAllByText"

let getAllByText = (~matcher, ~options=?, result) =>
  _getAllByText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryByText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTextQuery.options>,
) => Js.null<WebAPI.DOMAPI.element> = "queryByText"

let queryByText = (~matcher, ~options=?, result) =>
  _queryByText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryAllByText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTextQuery.options>,
) => array<WebAPI.DOMAPI.element> = "queryAllByText"

let queryAllByText = (~matcher, ~options=?, result) =>
  _queryAllByText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findByText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTextQuery.options>,
) => promise<WebAPI.DOMAPI.element> = "findByText"

let findByText = (~matcher, ~options=?, result) =>
  _findByText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findAllByText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTextQuery.options>,
) => promise<array<WebAPI.DOMAPI.element>> = "findAllByText"

let findAllByText = (~matcher, ~options=?, result) =>
  _findAllByText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

// ByAltText
@send
external _getByAltText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByAltTextQuery.options>,
) => WebAPI.DOMAPI.element = "getByAltText"

let getByAltText = (~matcher, ~options=?, result) =>
  _getByAltText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _getAllByAltText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByAltTextQuery.options>,
) => array<WebAPI.DOMAPI.element> = "getAllByAltText"

let getAllByAltText = (~matcher, ~options=?, result) =>
  _getAllByAltText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryByAltText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByAltTextQuery.options>,
) => Js.null<WebAPI.DOMAPI.element> = "queryByAltText"

let queryByAltText = (~matcher, ~options=?, result) =>
  _queryByAltText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryAllByAltText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByAltTextQuery.options>,
) => array<WebAPI.DOMAPI.element> = "queryAllByAltText"

let queryAllByAltText = (~matcher, ~options=?, result) =>
  _queryAllByAltText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findByAltText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByAltTextQuery.options>,
) => promise<WebAPI.DOMAPI.element> = "findByAltText"

let findByAltText = (~matcher, ~options=?, result) =>
  _findByAltText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findAllByAltText: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByAltTextQuery.options>,
) => promise<array<WebAPI.DOMAPI.element>> = "findAllByAltText"

let findAllByAltText = (~matcher, ~options=?, result) =>
  _findAllByAltText(result, ~matcher, ~options=Js.Undefined.fromOption(options))

// ByTitle
@send
external _getByTitle: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTitleQuery.options>,
) => WebAPI.DOMAPI.element = "getByTitle"

let getByTitle = (~matcher, ~options=?, result) =>
  _getByTitle(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _getAllByTitle: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTitleQuery.options>,
) => array<WebAPI.DOMAPI.element> = "getAllByTitle"

let getAllByTitle = (~matcher, ~options=?, result) =>
  _getAllByTitle(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryByTitle: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTitleQuery.options>,
) => Js.null<WebAPI.DOMAPI.element> = "queryByTitle"

let queryByTitle = (~matcher, ~options=?, result) =>
  _queryByTitle(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryAllByTitle: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTitleQuery.options>,
) => array<WebAPI.DOMAPI.element> = "queryAllByTitle"

let queryAllByTitle = (~matcher, ~options=?, result) =>
  _queryAllByTitle(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findByTitle: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTitleQuery.options>,
) => promise<WebAPI.DOMAPI.element> = "findByTitle"

let findByTitle = (~matcher, ~options=?, result) =>
  _findByTitle(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findAllByTitle: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTitleQuery.options>,
) => promise<array<WebAPI.DOMAPI.element>> = "findAllByTitle"

let findAllByTitle = (~matcher, ~options=?, result) =>
  _findAllByTitle(result, ~matcher, ~options=Js.Undefined.fromOption(options))

// ByDisplayValue
@send
external _getByDisplayValue: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByDisplayValueQuery.options>,
) => WebAPI.DOMAPI.element = "getByDisplayValue"

let getByDisplayValue = (~matcher, ~options=?, result) =>
  _getByDisplayValue(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _getAllByDisplayValue: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByDisplayValueQuery.options>,
) => array<WebAPI.DOMAPI.element> = "getAllByDisplayValue"

let getAllByDisplayValue = (~matcher, ~options=?, result) =>
  _getAllByDisplayValue(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryByDisplayValue: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByDisplayValueQuery.options>,
) => Js.null<WebAPI.DOMAPI.element> = "queryByDisplayValue"

let queryByDisplayValue = (~matcher, ~options=?, result) =>
  _queryByDisplayValue(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryAllByDisplayValue: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByDisplayValueQuery.options>,
) => array<WebAPI.DOMAPI.element> = "queryAllByDisplayValue"

let queryAllByDisplayValue = (~matcher, ~options=?, result) =>
  _queryAllByDisplayValue(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findByDisplayValue: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByDisplayValueQuery.options>,
) => promise<WebAPI.DOMAPI.element> = "findByDisplayValue"

let findByDisplayValue = (~matcher, ~options=?, result) =>
  _findByDisplayValue(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findAllByDisplayValue: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByDisplayValueQuery.options>,
) => promise<array<WebAPI.DOMAPI.element>> = "findAllByDisplayValue"

let findAllByDisplayValue = (~matcher, ~options=?, result) =>
  _findAllByDisplayValue(result, ~matcher, ~options=Js.Undefined.fromOption(options))

// ByRole
@send
external _getByRole: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByRoleQuery.options>,
) => WebAPI.DOMAPI.element = "getByRole"

let getByRole = (~matcher, ~options=?, result) =>
  _getByRole(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _getAllByRole: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByRoleQuery.options>,
) => array<WebAPI.DOMAPI.element> = "getAllByRole"

let getAllByRole = (~matcher, ~options=?, result) =>
  _getAllByRole(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryByRole: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByRoleQuery.options>,
) => Js.null<WebAPI.DOMAPI.element> = "queryByRole"

let queryByRole = (~matcher, ~options=?, result) =>
  _queryByRole(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryAllByRole: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByRoleQuery.options>,
) => array<WebAPI.DOMAPI.element> = "queryAllByRole"

let queryAllByRole = (~matcher, ~options=?, result) =>
  _queryAllByRole(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findByRole: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByRoleQuery.options>,
) => promise<WebAPI.DOMAPI.element> = "findByRole"

let findByRole = (~matcher, ~options=?, result) =>
  _findByRole(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findAllByRole: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByRoleQuery.options>,
) => promise<array<WebAPI.DOMAPI.element>> = "findAllByRole"

let findAllByRole = (~matcher, ~options=?, result) =>
  _findAllByRole(result, ~matcher, ~options=Js.Undefined.fromOption(options))

// ByTestId
@send
external _getByTestId: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTestIdQuery.options>,
) => WebAPI.DOMAPI.element = "getByTestId"

let getByTestId = (~matcher, ~options=?, result) =>
  _getByTestId(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _getAllByTestId: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTestIdQuery.options>,
) => array<WebAPI.DOMAPI.element> = "getAllByTestId"

let getAllByTestId = (~matcher, ~options=?, result) =>
  _getAllByTestId(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryByTestId: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTestIdQuery.options>,
) => Js.null<WebAPI.DOMAPI.element> = "queryByTestId"

let queryByTestId = (~matcher, ~options=?, result) =>
  _queryByTestId(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _queryAllByTestId: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTestIdQuery.options>,
) => array<WebAPI.DOMAPI.element> = "queryAllByTestId"

let queryAllByTestId = (~matcher, ~options=?, result) =>
  _queryAllByTestId(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findByTestId: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTestIdQuery.options>,
) => promise<WebAPI.DOMAPI.element> = "findByTestId"

let findByTestId = (~matcher, ~options=?, result) =>
  _findByTestId(result, ~matcher, ~options=Js.Undefined.fromOption(options))

@send
external _findAllByTestId: (
  renderResult,
  ~matcher: @unwrap
  [#Str(string) | #RegExp(Js.Re.t) | #Func((string, WebAPI.DOMAPI.element) => bool)],
  ~options: Js.undefined<ByTestIdQuery.options>,
) => promise<array<WebAPI.DOMAPI.element>> = "findAllByTestId"

let findAllByTestId = (~matcher, ~options=?, result) =>
  _findAllByTestId(result, ~matcher, ~options=Js.Undefined.fromOption(options))

let render = (~baseElement=?, ~container=?, ~hydrate=?, ~wrapper=?, ~queries=?, element) => {
  let baseElement_ = switch container {
  | Some(container') => Js.Undefined.return(container')
  | None => Js.Undefined.fromOption(baseElement)
  }
  let container_ = Js.Undefined.fromOption(container)

  _render(
    element,
    {
      "baseElement": baseElement_,
      "container": container_,
      "hydrate": Js.Undefined.fromOption(hydrate),
      "wrapper": Js.Undefined.fromOption(wrapper),
      "queries": Js.Undefined.fromOption(queries),
    },
  )
}

type result<'a> = {
  all: array<'a>,
  current: 'a,
  error: JsExn.t,
}

type renderHookResult<'a, 'b> = {
  result: result<'b>,
  rerender: 'a => unit,
  unmount: unit => unit,
}

type reactHookWrapperProps = {children: React.element}

@module("@testing-library/react")
external renderHookWithOptions: (
  'a => 'b,
  {"wrapper": reactHookWrapperProps => React.element},
) => renderHookResult<'a, 'b> = "renderHook"

@module("@testing-library/react")
external renderHookWithInitialProps: ('a => 'b, {"initialProps": 'a}) => renderHookResult<'a, 'b> =
  "renderHook"

@module("@testing-library/react")
external renderHook: ('a => 'b) => renderHookResult<'a, 'b> = "renderHook"

@module("@testing-library/react")
external act: (unit => unit) => unit = "act"

type waitForOptions = {timeout: int}

@module("@testing-library/react")
external waitFor: (unit => 'a) => promise<'a> = "waitFor"

@module("@testing-library/react")
external waitForOptions: (unit => 'a, waitForOptions) => promise<'a> = "waitFor"

@module("@testing-library/react")
external waitForPromise: (unit => promise<'a>) => promise<'a> = "waitFor"

@module("@testing-library/react")
external waitForPromiseWithTimeout: (unit => promise<'a>, waitForOptions) => promise<'a> = "waitFor"

@module("@testing-library/react")
external waitForElementToBeRemoved: (unit => 'a, waitForOptions) => promise<'a> =
  "waitForElementToBeRemoved"

let _replaceWhitespaces = string =>
  string
  ->String.replaceAll("\t", "")
  ->String.replaceAll("\n", "")
  ->String.replaceAll(" ", "")

// Note(bartosz.ka): This function might throw but this is intended to be used only in testing anyway
let contains = (renderResult: renderResult, component: React.element): bool => {
  let renderResultDOM =
    renderResult.baseElement->Option.getOrThrow->prettyDOMLimitless->_replaceWhitespaces

  let componentDOM =
    render(component).container
    ->Option.getOrThrow
    ->WebAPI.Element.querySelector("div > *")
    ->Null.getOrThrow
    ->prettyDOMLimitless
    ->_replaceWhitespaces

  renderResultDOM->String.includes(componentDOM)
}
