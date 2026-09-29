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

let decodeError = message => {
  let normalized = message->String.toLowerCase
  normalized->String.includes("source image cannot be decoded") ||
    normalized->String.includes("invalid encoded image data")
}

let captureErrorMessage = (message: string) =>
  switch decodeError(message) {
  | true => `Screenshot could not be rendered because the browser could not decode the generated page image. The page may contain malformed HTML, unsupported SVG content, or exceed browser image limits. Try again after the page finishes loading or capture a smaller element with the selector option.`
  | false => message
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

      let viewport: option<FrontmanBindings.Bindings__Snapdom.clip> = switch (
        fullPage,
        input.selector,
      ) {
      | (false, None) =>
        Some({
          x: win->WebAPI.Window.scrollX,
          y: win->WebAPI.Window.scrollY,
          width: win->WebAPI.Window.innerWidth->Int.toFloat,
          height: win->WebAPI.Window.innerHeight->Int.toFloat,
        })
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
            let (options, scale, dpr) = switch viewport {
            | Some(clip) => (
                Some({FrontmanBindings.Bindings__Snapdom.clip, reconcile: true}),
                Math.min(
                  1.0,
                  limits.maxDimension->Int.toFloat /. Math.max(clip.width, clip.height),
                ),
                Some(1.0),
              )
            | None => (None, Client__ImageLimits.computeScale(element, limits.maxDimension), None)
            }
            let captureResult = await FrontmanBindings.Bindings__Snapdom.snapdom(element, ~options?)
            let jpgImage = await captureResult.toJpg({scale, quality: limits.quality, ?dpr})
            imageResultFromDataUrl(jpgImage.src)
          } catch {
          | exn =>
            let message = Client__Tool__PreviewContext.exnMessage(exn)
            Tool.MCP.CallToolResult.makeError(captureErrorMessage(message))
          }
        }
      }
    },
  )
}
