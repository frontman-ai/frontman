module Preview = FrontmanAiFrontmanProtocol.FrontmanProtocol__Preview

let executeWithDocument = (input: Preview.getDomInput, ~document) =>
  try {
    FrontmanAiFrontmanCore.FrontmanCore__DomSnapshot.inspect(
      input,
      ~document,
      ~additionalAttributes=[],
      ~componentForElement=_ => None,
    )->Result.map(((output, _element)) => output)
  } catch {
  | exn =>
    Preview.getDomError(
      ~error=FrontmanAiFrontmanCore.FrontmanCore__ElementInspector.errorMessage(exn),
    )
  }

let execute = input =>
  executeWithDocument(input, ~document=WebAPI.Window.current->WebAPI.Window.document)
