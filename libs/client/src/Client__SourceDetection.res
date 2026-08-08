let getElementSourceLocation = async (
  ~element: WebAPI.DOMAPI.element,
  ~window: WebAPI.DOMAPI.window,
): option<Client__Types.SourceLocation.t> => {
  let reactResult = await Client__DOMElementToComponentSource.getElementSourceLocation(~element)

  switch reactResult {
  | Some(_) => reactResult
  | None =>
    let vueResult = Client__Vue__SourceDetection.getElementSourceLocation(~element)

    switch vueResult {
    | Some(_) => vueResult
    | None => Client__AstroSourceDetection.getElementSourceLocation(~element, ~window)
    }
  }
}
