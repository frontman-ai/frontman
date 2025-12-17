// Client tool that takes a screenshot of the web preview using Snapdom
// Captures the document body from the previewFrame

S.enableJson()
module Tool = AskTheLlmFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = "take_screenshot"
let description = "Take a screenshot of the current web preview page. Returns a base64-encoded PNG image data URL of the page body."

@schema
type input = {
  @s.describe("Optional CSS selector to screenshot a specific element instead of the whole page")
  selector: option<string>,
}

@schema
type output = {
  @s.describe("Base64-encoded PNG image data URL (data:image/png;base64,...)")
  screenshot: option<string>,
  @s.describe("Error message if the screenshot could not be taken")
  error: option<string>,
}

let execute = async (input: input): toolResult<output> => {
  let state = AskTheLlmReactStatestore.StateStore.getState(Client__State__Store.store)

  // Get the current task's preview frame
  let previewFrame =
    state.currentTaskId
    ->Option.flatMap(taskId => Dict.get(state.tasks, taskId))
    ->Option.map(task => task.previewFrame)

  switch previewFrame {
  | None => Ok({screenshot: None, error: Some("No active task with preview frame")})
  | Some({contentDocument: None, _}) =>
    Ok({screenshot: None, error: Some("Preview frame document not available")})
  | Some({contentDocument: Some(doc), _}) =>
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
        let captureResult = await Bindings__Snapdom.snapdom(~element)
        let pngImage = await captureResult.toPng(~options={scale: 2.0})
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

