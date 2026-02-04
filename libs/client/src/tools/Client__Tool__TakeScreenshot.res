// Client tool that takes a screenshot of the web preview using Snapdom
// Captures the document body from the previewFrame

S.enableJson()
module Tool = FrontmanFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = "take_screenshot"
let visibleToAgent = true
let description = "Take a screenshot of the current web preview page. Returns a base64-encoded JPEG image data URL of the page body."

@schema
type input = {
  @s.describe("Optional CSS selector to screenshot a specific element instead of the whole page")
  selector: option<string>,
}

@schema
type output = {
  @s.describe("Base64-encoded JPEG image data URL (data:image/jpeg;base64,...)")
  screenshot: option<string>,
  @s.describe("Error message if the screenshot could not be taken")
  error: option<string>,
}

let execute = async (input: input): toolResult<output> => {
  let state = FrontmanReactStatestore.StateStore.getState(Client__State__Store.store)

  // Get the current task's preview frame
  let previewFrame = Client__State__StateReducer.Selectors.previewFrame(state)

  switch previewFrame.contentDocument {
  | None => Ok({screenshot: None, error: Some("Preview frame document not available")})
  | Some(doc) =>
    // Get the element to screenshot
    let elementResult = switch input.selector {
    | Some(selector) =>
      doc
      ->WebAPI.Document.querySelector(selector)
      ->Null.toOption
      ->Option.mapOr(Error(`Element not found for selector: ${selector}`), el => Ok(el))
    | None =>
      doc
      ->WebAPI.Document.body
      ->Null.toOption
      ->Option.mapOr(Error("Document body not available"), el => Ok(el->Obj.magic))
    }

    switch elementResult {
    | Error(err) => Ok({screenshot: None, error: Some(err)})
    | Ok(element) =>
      try {
        let captureResult = await Bindings__Snapdom.snapdom(element)
        let pngImage = await captureResult.toJpg({scale: 1.0})
        Ok({screenshot: Some(pngImage.src), error: None})
      } catch {
      | exn =>
        let errorMsg =
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("Unknown error capturing screenshot")
        Ok({screenshot: None, error: Some(errorMsg)})
      }
    }
  }
}
