// Client tool that takes a screenshot of the web preview using Snapdom
// Captures the document body from the previewFrame

S.enableJson()
module Tool = FrontmanFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.takeScreenshot
let visibleToAgent = true
let description = "Take a screenshot of the current web preview page. By default captures only the visible viewport. Set fullPage to true to capture the entire scrollable page. Returns a base64-encoded JPEG image data URL."

@schema
type input = {
  @s.describe("Optional CSS selector to screenshot a specific element instead of the page")
  selector: option<string>,
  @s.describe("When true, captures the entire scrollable page instead of just the visible viewport. Defaults to false.")
  fullPage: option<bool>,
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

let _conservativeLimits: imageLimits = {maxDimension: 7680, quality: 0.8}

let _limitsForProvider = (provider: option<string>): imageLimits =>
  switch provider {
  | Some("anthropic") => {maxDimension: 7680, quality: 0.8}
  | Some("openai" | "chatgpt") => {maxDimension: 0, quality: 0.8}
  | Some("openrouter") => {maxDimension: 7680, quality: 0.8}
  | None => _conservativeLimits
  | Some(unknown) =>
    Console.warn2("[TakeScreenshot] Unknown provider, using conservative limits:", unknown)
    _conservativeLimits
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

// Crop a canvas to viewport dimensions at the current scroll position.
// Returns a JPEG data URL of just the visible viewport area.
//
// All coordinates are in CSS pixels. The `scale` param accounts for
// snapdom's scale factor (from _computeScale) which may shrink the canvas
// relative to CSS dimensions to stay within provider pixel limits.
// snapdom's toCanvas defaults to dpr=1, so canvas pixels = CSS pixels × scale.
let _cropCanvasToViewport = (
  sourceCanvas: WebAPI.DOMAPI.htmlCanvasElement,
  ~scrollX: float,
  ~scrollY: float,
  ~viewportW: int,
  ~viewportH: int,
  ~scale: float,
  ~quality: float,
): string => {
  open WebAPI

  let qualityJson = JSON.Encode.float(quality)

  // Convert CSS-pixel coordinates to canvas-pixel coordinates
  let sx = Math.round(scrollX *. scale)
  let sy = Math.round(scrollY *. scale)
  let sw = Math.round(viewportW->Int.toFloat *. scale)
  let sh = Math.round(viewportH->Int.toFloat *. scale)

  // Clamp to source canvas bounds
  let sx = Math.max(sx, 0.0)
  let sy = Math.max(sy, 0.0)
  let sw = Math.min(sw, sourceCanvas.width->Int.toFloat -. sx)
  let sh = Math.min(sh, sourceCanvas.height->Int.toFloat -. sy)

  if sw <= 0.0 || sh <= 0.0 {
    sourceCanvas->HTMLCanvasElement.toDataURL(~type_="image/jpeg", ~quality=qualityJson)
  } else {
    // Create cropped canvas
    let crop = Global.document->Document.createCanvasElement
    crop.width = sw->Float.toInt
    crop.height = sh->Float.toInt
    let ctx = crop->HTMLCanvasElement.getContext_2D

    ctx->CanvasRenderingContext2D.drawImageWithCanvasSubRectangle(
      ~image=sourceCanvas,
      ~sx,
      ~sy,
      ~sw,
      ~sh,
      ~dx=0.0,
      ~dy=0.0,
      ~dw=sw,
      ~dh=sh,
    )

    crop->HTMLCanvasElement.toDataURL(~type_="image/jpeg", ~quality=qualityJson)
  }
}

let execute = async (input: input): toolResult<output> => {
  let state = FrontmanReactStatestore.StateStore.getState(Client__State__Store.store)

  // Get the current task's preview frame
  let previewFrame = Client__State__StateReducer.Selectors.previewFrame(state)
  let fullPage = input.fullPage->Option.getOr(false)

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
      ->Option.mapOr(Error("Document body not available"), el => Ok(el))
    }

    // For viewport-only capture (no selector, not fullPage), gather scroll + dimensions
    let viewportCrop = switch (fullPage, input.selector) {
    | (false, None) =>
      previewFrame.contentWindow->Option.map(win => {
        (win.innerWidth, win.innerHeight, win.scrollX, win.scrollY)
      })
    | _ => None
    }

    switch elementResult {
    | Error(err) => Ok({screenshot: None, error: Some(err)})
    | Ok(element) =>
      let rect = element->WebAPI.Element.getBoundingClientRect
      if rect.width <= 0.0 || rect.height <= 0.0 {
        Ok({screenshot: None, error: Some("Target element has zero dimensions (may be hidden or not rendered)")})
      } else {
        try {
          let provider = state.selectedModel->Option.map(m => m.provider)
          let limits = _limitsForProvider(provider)
          let scale = _computeScale(element, limits.maxDimension)

          let captureResult = await Bindings__Snapdom.snapdom(element)

          switch viewportCrop {
          | Some((viewportW, viewportH, scrollX, scrollY)) =>
            // Viewport mode: render full page to canvas, then crop to visible area
            let canvas = await captureResult.toCanvas({scale: scale})
            let dataUrl = _cropCanvasToViewport(
              canvas,
              ~scrollX,
              ~scrollY,
              ~viewportW,
              ~viewportH,
              ~scale,
              ~quality=limits.quality,
            )
            Ok({screenshot: Some(dataUrl), error: None})
          | None =>
            // Full page / selector mode: export directly as JPEG
            let jpgImage = await captureResult.toJpg({scale, quality: limits.quality})
            Ok({screenshot: Some(jpgImage.src), error: None})
          }
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
}
