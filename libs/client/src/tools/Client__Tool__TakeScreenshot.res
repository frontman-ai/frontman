// Client tool that takes a screenshot of the web preview using Snapdom
// Captures the document body from the previewFrame

S.enableJson()
module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.takeScreenshot
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = "Take a screenshot of the current web preview page. By default captures only the visible viewport. Set fullPage to true to capture the entire scrollable page. Returns a base64-encoded JPEG image data URL."

@schema
type input = {
  @s.describe("Optional CSS selector to screenshot a specific element instead of the page")
  selector: option<string>,
  @s.describe(
    "When true, captures the entire scrollable page instead of just the visible viewport. Defaults to false."
  )
  fullPage: option<bool>,
}

@schema
type output = {
  @s.describe("Base64-encoded JPEG image data URL (data:image/jpeg;base64,...)") @live
  screenshot: option<string>,
  @s.describe("Error message if the screenshot could not be taken") @live
  error: option<string>,
}

// Image limits and scale computation are shared via Client__ImageLimits
// to ensure all image capture paths use the same constraints.

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

let execute = async (
  input: input,
  ~taskId as _taskId: string,
  ~toolCallId as _toolCallId: string,
): toolResult<output> => {
  let fullPage = input.fullPage->Option.getOr(false)

  await Client__Tool__ElementResolver.withPreviewDoc(
    ~onUnavailable=async () => Ok({
      screenshot: None,
      error: Some("Preview frame document not available"),
    }),
    async ({doc, win}) => {
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
      | (false, None) => Some((win.innerWidth, win.innerHeight, win.scrollX, win.scrollY))
      | _ => None
      }

      switch elementResult {
      | Error(err) => Ok({screenshot: None, error: Some(err)})
      | Ok(element) =>
        let rect = element->WebAPI.Element.getBoundingClientRect
        if rect.width <= 0.0 || rect.height <= 0.0 {
          Ok({
            screenshot: None,
            error: Some("Target element has zero dimensions (may be hidden or not rendered)"),
          })
        } else {
          try {
            let state = StateStore.getState(Client__State__Store.store)
            let provider =
              state.selectedModelValue
              ->Option.flatMap(
                FrontmanAiFrontmanProtocol.FrontmanProtocol__Types.modelSelectionFromValueId,
              )
              ->Option.map(FrontmanAiFrontmanProtocol.FrontmanProtocol__Types.provider)
            let limits = Client__ImageLimits.forProvider(provider)
            let scale = Client__ImageLimits.computeScale(element, limits.maxDimension)

            let captureResult = await FrontmanBindings.Bindings__Snapdom.snapdom(element)

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
            Ok({screenshot: None, error: Some(Client__Tool__ElementResolver.exnMessage(exn))})
          }
        }
      }
    },
  )
}
