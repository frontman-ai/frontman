module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool

let name = Tool.ToolNames.takeScreenshot
let access = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Read
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Synchronous
let description = "Take a screenshot of the current web preview page. By default captures only the visible viewport. Set fullPage to true to capture the entire scrollable page."
let outputJsonSchema = None

@schema
type input = {
  @s.describe("Optional CSS selector to screenshot a specific element instead of the page")
  selector: option<string>,
  @s.describe(
    "When true, captures the entire scrollable page instead of just the visible viewport. Defaults to false."
  )
  fullPage: option<bool>,
}

let _cropCanvasToViewport = (
  sourceCanvas: WebAPI.DomTypes.htmlCanvasElement,
  ~scrollX: float,
  ~scrollY: float,
  ~viewportW: int,
  ~viewportH: int,
  ~scale: float,
  ~quality: float,
): string => {
  open WebAPI

  let qualityJson = JSON.Encode.float(quality)

  let sx = Math.round(scrollX *. scale)
  let sy = Math.round(scrollY *. scale)
  let sw = Math.round(viewportW->Int.toFloat *. scale)
  let sh = Math.round(viewportH->Int.toFloat *. scale)

  let sx = Math.max(sx, 0.0)
  let sy = Math.max(sy, 0.0)
  let sw = Math.min(sw, sourceCanvas.width->Int.toFloat -. sx)
  let sh = Math.min(sh, sourceCanvas.height->Int.toFloat -. sy)

  if sw <= 0.0 || sh <= 0.0 {
    sourceCanvas->HTMLCanvasElement.toDataURL(~type_="image/jpeg", ~quality=qualityJson)
  } else {
    let crop = Window.current->Window.document->Document.createCanvasElement
    crop.width = sw->Float.toInt
    crop.height = sh->Float.toInt
    let ctx = crop->HTMLCanvasElement.getContext2D

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

let imageResultFromDataUrl = (dataUrl: string): Tool.MCP.CallToolResult.t => {
  switch dataUrl->String.split(",") {
  | [header, data] =>
    switch header->String.startsWith("data:image/jpeg;base64") {
    | true => Tool.imageResult(~data, ~mimeType="image/jpeg")
    | false =>
      Tool.MCP.CallToolResult.makeError(
        `Screenshot capture returned unsupported image data: ${dataUrl}`,
      )
    }
  | _ =>
    Tool.MCP.CallToolResult.makeError(
      `Screenshot capture returned malformed image data: ${dataUrl}`,
    )
  }
}

let execute = async (
  input: input,
  ~taskId as _taskId: string,
  ~toolCallId as _toolCallId: string,
): Tool.MCP.CallToolResult.t => {
  let fullPage = input.fullPage->Option.getOr(false)

  await Client__Tool__PreviewContext.withPreview(
    ~onUnavailable=async () =>
      Tool.MCP.CallToolResult.makeError("Preview frame document not available"),
    async ({doc, win}) => {
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
        ->Option.mapOr(Error("Document body not available"), el => Ok(
          el->WebAPI.HTMLElement.asElement,
        ))
      }

      let viewportCrop = switch (fullPage, input.selector) {
      | (false, None) =>
        Some((
          win->WebAPI.Window.innerWidth,
          win->WebAPI.Window.innerHeight,
          win->WebAPI.Window.scrollX,
          win->WebAPI.Window.scrollY,
        ))
      | _ => None
      }

      switch elementResult {
      | Error(err) => Tool.MCP.CallToolResult.makeError(err)
      | Ok(element) =>
        let rect = element->WebAPI.Element.getBoundingClientRect
        if rect.width <= 0.0 || rect.height <= 0.0 {
          Tool.MCP.CallToolResult.makeError(
            "Target element has zero dimensions (may be hidden or not rendered)",
          )
        } else {
          try {
            let limits = Client__ImageLimits.conservative
            let scale = Client__ImageLimits.computeScale(element, limits.maxDimension)

            let captureResult = await FrontmanBindings.Bindings__Snapdom.snapdom(element)

            switch viewportCrop {
            | Some((viewportW, viewportH, scrollX, scrollY)) =>
              let canvas = await captureResult.toCanvas({scale, dpr: 1.0})
              let dataUrl = _cropCanvasToViewport(
                canvas,
                ~scrollX,
                ~scrollY,
                ~viewportW,
                ~viewportH,
                ~scale,
                ~quality=limits.quality,
              )
              imageResultFromDataUrl(dataUrl)
            | None =>
              let jpgImage = await captureResult.toJpg({scale, quality: limits.quality})
              imageResultFromDataUrl(jpgImage.src)
            }
          } catch {
          | exn => Tool.MCP.CallToolResult.makeError(Client__Tool__PreviewContext.exnMessage(exn))
          }
        }
      }
    },
  )
}
