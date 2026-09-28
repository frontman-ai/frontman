let getElementSourceLocation = async (
  ~element: WebAPI.DomTypes.element,
  ~window: WebAPI.DomTypes.window,
): option<Client__SourceContext.t> => {
  let reactResult = await Client__DOMElementToComponentSource.getElementSourceContext(~element)

  switch reactResult {
  | Some(_) => reactResult
  | None =>
    let vueResult = Client__Vue__SourceDetection.getElementSourceLocation(~element)

    switch vueResult {
    | Some(location) => Some(Client__SourceContext.fromDefinition(location))
    | None =>
      Client__AstroSourceDetection.getElementSourceLocation(~element, ~window)->Option.map(
        Client__SourceContext.fromDefinition,
      )
    }
  }
}
