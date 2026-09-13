module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview

let execute = (input: Preview.getDomInput) =>
  try {
    FrontmanAiFrontmanCore.FrontmanCore__DomSnapshot.inspect(
      input,
      ~document=WebAPI.Window.current->WebAPI.Window.document,
      ~additionalAttributes=[],
      ~componentForElement=_ => None,
    )->Result.map(((output, _element)) => output)
  } catch {
  | exn => Error(FrontmanAiFrontmanCore.FrontmanCore__ElementInspector.errorMessage(exn))
  }
