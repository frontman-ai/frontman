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

// Provider-specific image constraints for screenshot capture.
// Applied client-side before sending images to avoid API rejections.
//
// Anthropic: hard 8000px limit per dimension — API rejects anything larger.
//            We use 7680 for margin.
// OpenAI:    auto-resizes internally, no hard pixel rejection.
// OpenRouter: routes to various backends; use Anthropic's limit as a
//            conservative floor since many models are Anthropic-backed.
type imageLimits = {
  maxDimension: int, // max px on any side; 0 = no limit
  quality: float, // JPEG quality 0.0–1.0
}

let _limitsForProvider = (provider: string): imageLimits =>
  switch provider {
  | "anthropic" => {maxDimension: 7680, quality: 0.8}
  | "openai" | "chatgpt" => {maxDimension: 0, quality: 0.8}
  | "openrouter" => {maxDimension: 7680, quality: 0.8}
  | _ => {maxDimension: 7680, quality: 0.8}
  }

// Compute a scale factor that keeps both width and height within maxDimension.
// When maxDimension is 0 (no limit) or the element already fits, returns 1.0.
//
// getBoundingClientRect returns CSS pixels. On hi-DPI displays the rendered
// canvas is DPR× larger, so we multiply by devicePixelRatio to get the
// effective pixel dimensions that will be sent to the API.
let _computeScale = (element: WebAPI.DOMAPI.element, maxDimension: int): float => {
  if maxDimension <= 0 {
    1.0
  } else {
    let dpr = WebAPI.Global.devicePixelRatio
    let rect = element->WebAPI.Element.getBoundingClientRect
    let maxSide = Math.max(rect.width *. dpr, rect.height *. dpr)
    if maxSide <= 0.0 || maxSide <= maxDimension->Int.toFloat {
      1.0
    } else {
      maxDimension->Int.toFloat /. maxSide
    }
  }
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
        let provider =
          state.selectedModel->Option.map(m => m.provider)->Option.getOr("")
        let limits = _limitsForProvider(provider)
        let scale = _computeScale(element, limits.maxDimension)
        let captureResult = await Bindings__Snapdom.snapdom(element)
        let jpgImage = await captureResult.toJpg({scale, quality: limits.quality})
        Ok({screenshot: Some(jpgImage.src), error: None})
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
