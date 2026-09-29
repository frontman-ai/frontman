open Vitest
open WebAPI

module Task = Client__State__Types.Task

@send
external createIframe: (DomTypes.document, @as("iframe") _) => DomTypes.htmliFrameElement =
  "createElement"
@new external makeImage: unit => DomTypes.htmlImageElement = "Image"

let originalState = StateStore.getState(Client__State__Store.store)

afterEach(() => {
  DomGlobal.document
  ->Document.querySelector("#screenshot-preview")
  ->Null.toOption
  ->Option.forEach(Element.remove)
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    originalState,
  )
})

let checkVisibleMarker = async (t, ~bodyStyle, ~markerStyle, ~scrollY) => {
  let frame = DomGlobal.document->createIframe
  frame->HTMLIFrameElement.setAttribute(~qualifiedName="id", ~value="screenshot-preview")
  frame->HTMLIFrameElement.setAttribute(
    ~qualifiedName="style",
    ~value="width:800px;height:600px;border:0",
  )
  DomGlobal.document.body->HTMLElement.appendChild(frame->HTMLIFrameElement.asNode)->ignore
  let doc = frame->HTMLIFrameElement.contentDocument->Option.getOrThrow
  let win = frame->HTMLIFrameElement.contentWindow->Option.getOrThrow
  doc->Document.write(
    `<!doctype html><style>
    html {background:white} body {margin:0;height:1400px;${bodyStyle}}
    #brand {width:100px;height:50px;background:red;${markerStyle}}
    </style><div id="brand"></div>`,
  )
  doc->Document.close
  win->Window.scrollToXY(~x=0.0, ~y=scrollY)
  await Promise.make((resolve, _) => win->Window.requestAnimationFrame(_ => resolve())->ignore)

  let task =
    Task.makeNew(~previewUrl="about:blank")->Client__Task__Reducer.Lens.setPreviewFrame(
      ~contentDocument=Some(doc),
      ~contentWindow=Some(win),
    )
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    {...originalState, currentTask: Task.New(task)},
  )
  let rect = doc->Document.querySelector("#brand")->Null.getOrThrow->Element.getBoundingClientRect
  t->expect(win->Window.scrollY)->Expect.toBe(scrollY)
  let result = await Client__Tool__TakeScreenshot.execute(
    {selector: None, fullPage: None},
    ~taskId="screenshot-test",
    ~toolCallId="capture-test",
  )
  let content =
    result->S.decodeOrThrow(
      ~from=FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP.CallToolResult.schema,
      ~to=S.object(s =>
        s.field("content", FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock.arraySchema)
      ),
    )
  let image = makeImage()
  image.src = switch content {
  | [ImageContent({data, mimeType})] => `data:${mimeType};base64,${data}`
  | _ => failwith("Screenshot must return image content")
  }
  await image->HTMLImageElement.decode
  t->expect((image.naturalWidth, image.naturalHeight))->Expect.toEqual((800, 600))
  let canvas = DomGlobal.document->Document.createCanvasElement
  canvas.width = image.naturalWidth
  canvas.height = image.naturalHeight
  let ctx = canvas->HTMLCanvasElement.getContext2D
  ctx->CanvasRenderingContext2D.drawImage(~image, ~dx=0.0, ~dy=0.0)
  [
    (rect.left +. 2.0, rect.top +. 2.0, true),
    (rect.right -. 3.0, rect.bottom -. 3.0, true),
    (rect.right +. 2.0, rect.top +. rect.height /. 2.0, false),
    (rect.left +. rect.width /. 2.0, rect.bottom +. 2.0, false),
  ]->Array.forEach(((x, y, expectedRed)) => {
    let pixel =
      ctx->CanvasRenderingContext2D.getImageData(
        ~sx=x->Float.toInt,
        ~sy=y->Float.toInt,
        ~sw=1,
        ~sh=1,
      )
    let isRed =
      pixel.data->TypedArray.get(0)->Option.getOrThrow > 200 &&
      pixel.data->TypedArray.get(1)->Option.getOrThrow < 50 &&
      pixel.data->TypedArray.get(2)->Option.getOrThrow < 50
    t->expect((x, y, isRed))->Expect.toEqual((x, y, expectedRed))
  })
  t->expect(win->Window.scrollY)->Expect.toBe(scrollY)
}

testAsync("viewport capture preserves body margins", async t => {
  await checkVisibleMarker(t, ~bodyStyle="margin:40px", ~markerStyle="", ~scrollY=0.0)
})

testAsync("viewport capture keeps a fixed header visible after scrolling", async t => {
  await checkVisibleMarker(t, ~bodyStyle="", ~markerStyle="position:fixed;top:0", ~scrollY=400.0)
})
