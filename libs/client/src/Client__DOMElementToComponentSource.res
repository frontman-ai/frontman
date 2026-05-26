@@live
type getElementSourceLocationResult = {
  success: bool,
  data: Client__Types.SourceLocation.t,
  error: option<string>,
}
@module("dom-element-to-component-source")
external getElementSourceLocation: (
  ~element: WebAPI.DOMAPI.element,
) => promise<getElementSourceLocationResult> = "getElementSourceLocation"

let getElementSourceLocation = async (~element: WebAPI.DOMAPI.element) => {
  let result = await getElementSourceLocation(~element)
  switch result.success {
  | true => Some(result.data)
  | false => None
  }
}
