@@live
type getElementSourceContextResult = {
  success: bool,
  data: option<Client__SourceContext.t>,
  error: option<string>,
}

@module("dom-element-to-component-source")
external getElementSourceContextRaw: (
  ~element: WebAPI.DomTypes.element,
) => promise<getElementSourceContextResult> = "getElementSourceContext"

let getElementSourceContext = async (~element: WebAPI.DomTypes.element): option<
  Client__SourceContext.t,
> => {
  let result = await getElementSourceContextRaw(~element)
  switch result.success {
  | true => result.data
  | false => None
  }
}
