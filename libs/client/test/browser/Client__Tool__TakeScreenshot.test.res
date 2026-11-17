open Vitest
open WebAPI

module Task = Client__State__Types.Task

module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP
module ContentBlock = FrontmanAiFrontmanProtocol.FrontmanProtocol__ContentBlock

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

let checkVisibleMarker = async (t, ~style, ~scrollY) => {
  let frame =
    DomGlobal.document
    ->Document.createElement("iframe")
    ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
    ->Option.getOrThrow
  frame.id = "screenshot-preview"
  frame.style.cssText = "width:800px;height:600px;border:0"
  DomGlobal.document.body->HTMLElement.appendChild(frame->HTMLIFrameElement.asNode)->ignore
  let doc = frame->HTMLIFrameElement.contentDocument->Option.getOrThrow
  let win = frame->HTMLIFrameElement.contentWindow->Option.getOrThrow
  doc->Document.write(
    `<!doctype html><style>
    html {background:white} body {margin:0;height:1400px}
    #brand {width:100px;height:50px;background:red}
    ${style}
    </style><div id="brand"></div>`,
  )
  doc->Document.close
  win->Window.scrollToXY(~x=0.0, ~y=scrollY)
  await Promise.make((resolve, _) => win->Window.requestAnimationFrame(_ => resolve())->ignore)

  let task =
    Task.makeNew(~previewUrl="about:blank", ~clientId="screenshot")->Client__Task__Reducer.Lens.setPreviewFrame(
      ~contentDocument=Some(doc),
      ~contentWindow=Some({window: win}),
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
      ~from=MCP.CallToolResult.schema,
      ~to=S.object(s => s.field("content", ContentBlock.arraySchema)),
    )
  let image = Client__ImageLimits.makeImage()
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
  await checkVisibleMarker(t, ~style="body {margin:40px}", ~scrollY=0.0)
})

testAsync("viewport capture keeps a fixed header visible after scrolling", async t => {
  await checkVisibleMarker(t, ~style="#brand {position:fixed;top:0}", ~scrollY=400.0)
})

@get external detailsOpen: DomTypes.element => bool = "open"

let nextFrame = win =>
  Promise.make((resolve, _) => win->Window.requestAnimationFrame(_ => resolve())->ignore)

let settle = async win => {
  await Promise.make((resolve, _) =>
    win->Window.setTimeout(~handler=() => resolve(), ~timeout=0)->ignore
  )
  await nextFrame(win)
  await nextFrame(win)
}

let checkDisclosures = async (t, input: Client__Tool__TakeScreenshot.input, ~registry=false) => {
  let frame =
    DomGlobal.document
    ->Document.createElement("iframe")
    ->FrontmanBindings.Bindings__WebAPI.iframeElementFromElement
    ->Option.getOrThrow
  frame.id = "screenshot-preview"
  frame.style.cssText = "width:800px;height:600px;border:0"
  DomGlobal.document.body->HTMLElement.appendChild(frame->HTMLIFrameElement.asNode)->ignore
  let doc = frame->HTMLIFrameElement.contentDocument->Option.getOrThrow
  let win = frame->HTMLIFrameElement.contentWindow->Option.getOrThrow
  doc->Document.write(`<!doctype html><style>
    html {background:white} body {margin:0;min-height:1800px}
    #sentinels {height:64px}
    #target {width:640px;margin-left:40px}
    details,summary {margin:0;padding:0;border:0}
    summary {height:24px;line-height:24px}
    .answer {height:32px;background:rgb(224,32,32)}
    .visible {background:rgb(32,192,64)}
    .marker {height:8px;background:rgb(32,64,224)}
    summary.marker {height:24px}
    #below {margin-top:700px}
    #outside .answer {background:rgb(224,144,32)}
    </style>
    <div id="sentinels"><input id="input" value="markup value">
      <span id="text">Original text</span>
      <div id="scroller" style="height:20px;width:100px;overflow:auto">
        <div style="height:100px">Scroll sentinel</div>
      </div>
    </div>
    <main id="target">
      <details id="closed"><summary class="marker">Closed</summary><div class="answer"></div></details>
      <div id="after-closed" class="marker"></div>
      <details id="open" open="original"><summary>Open</summary><div id="open-answer" class="answer visible"></div></details>
      <div id="after-open" class="marker"></div>
      <details id="runtime" open><summary>Runtime closed</summary><div class="answer"></div></details>
      <div id="after-runtime" class="marker"></div>
      <details id="outer" open><summary>Outer open</summary>
        <details id="nested-closed"><summary>Nested closed</summary><div class="answer"></div></details>
        <div id="after-nested-closed" class="marker"></div>
        <details id="nested-open" open><summary>Nested open</summary><div id="nested-answer" class="answer visible"></div></details>
        <div id="after-nested-open" class="marker"></div>
      </details>
      <div id="after-outer" class="marker"></div>
      <details id="peer-closed" name="faq"><summary>Peer closed</summary><div class="answer"></div></details>
      <div id="after-peer-closed" class="marker"></div>
      <details id="peer-open" name="faq" open><summary>Peer open</summary><div id="peer-answer" class="answer visible"></div></details>
      <div id="after-peer-open" class="marker"></div>
      <div id="below">
        <details id="below-closed"><summary>Below fold closed</summary><div class="answer"></div></details>
        <div id="after-below-closed" class="marker"></div>
        <details id="below-open" open><summary>Below fold open</summary><div id="below-answer" class="answer visible"></div></details>
        <div id="after-below-open" class="marker"></div>
      </div>
      <div id="visibility" style="content-visibility:auto;contain-intrinsic-size:80px;height:80px">
        Visibility sentinel
      </div>
      <div id="bottom" class="marker"></div>
    </main>
    <details id="outside" open><summary>Unrelated outside target</summary><div id="outside-answer" class="answer"></div></details>
    <div id="after-outside" class="marker"></div>`)
  doc->Document.close
  let query = selector => doc->Document.querySelector(selector)->Null.getOrThrow
  query("#runtime")->Element.removeAttribute("open")
  let control = query("#input")->FrontmanBindings.Bindings__WebAPI.unsafeInputElementFromElement
  control.value = "Runtime input value"
  let text = query("#text")
  text.textContent = Null.make("Runtime text sentinel")
  control->HTMLInputElement.focus(~options={preventScroll: true})
  let scroller = query("#scroller")
  scroller.scrollTop = 17.0
  win->Window.scrollToXY(~x=0.0, ~y=16.0)
  await settle(win)

  let task =
    Task.makeNew(~previewUrl="about:blank", ~clientId="screenshot")->Client__Task__Reducer.Lens.setPreviewFrame(
      ~contentDocument=Some(doc),
      ~contentWindow=Some({window: win}),
    )
  StateStore.forceSetStateOnlyUseForTestingDoNotUseOtherwiseAtAll(
    Client__State__Store.store,
    {...originalState, currentTask: Task.New(task)},
  )
  let details =
    doc->Document.querySelectorAll("details")->NodeList.toArray->Array.map(node => (
      node,
      detailsOpen(node),
      node->Element.getAttribute("open"),
      node->Element.getBoundingClientRect,
    ))
  t->expect(details->Array.map(((_, isOpen, _, _)) => isOpen))->Expect.toEqual([
    false, true, false, true, false, true, false, true, false, true, true,
  ])
  ["#closed", "#runtime", "#nested-closed", "#peer-closed", "#below-closed"]->Array.forEach(
    selector =>
      t->expect((query(selector)->Element.getBoundingClientRect).height)->Expect.toBe(24.0),
  )
  t->expect((query("#below")->Element.getBoundingClientRect).top > 600.0)->Expect.toBe(true)
  t->expect(doc.activeElement->Null.getOrThrow)->Expect.toBe(control->HTMLInputElement.asElement)
  t->expect(win->Window.scrollY)->Expect.toBe(16.0)
  t->expect(scroller.scrollTop)->Expect.toBe(17.0)
  let focused = doc.activeElement
  let scroll = (win->Window.scrollX, win->Window.scrollY, scroller.scrollTop)
  let visibility = query("#visibility")
  let visibilityStyle = () =>
    ["content-visibility", "contain-intrinsic-size", "height"]->Array.map(property =>
      visibility->FrontmanBindings.Bindings__WebAPI.unsafeHtmlElementFromElement
      ->HTMLElement.style->CSSStyleDeclaration.getPropertyValue(property)
    )
  let style = visibilityStyle()
  let toggles = ref(0)
  let onToggle = _ => toggles := toggles.contents + 1
  details->Array.forEach(((node, _, _, _)) => node->Element.addEventListener(Toggle, onToggle))
  let mutations = ref(0)
  let observer = MutationObserver.make((records, _) =>
    mutations := mutations.contents + records->Array.length
  )
  observer->MutationObserver.observe(
    ~target=doc->Document.asNode,
    ~options={attributes: true, subtree: true, attributeFilter: ["open"]},
  )
  let assertLiveState = () => {
    details->Array.forEach(((node, isOpen, attr, rect)) => {
      t->expect(query(`#${node.id}`))->Expect.toBe(node)
      t
      ->expect((detailsOpen(node), node->Element.getAttribute("open")))
      ->Expect.toEqual((isOpen, attr))
      let current = node->Element.getBoundingClientRect
      t->expect((current.top, current.height))->Expect.toEqual((rect.top, rect.height))
    })
    t
    ->expect(mutations.contents + (observer->MutationObserver.takeRecords->Array.length))
    ->Expect.toBe(0)
    t->expect(toggles.contents)->Expect.toBe(0)
    t->expect(control.value)->Expect.toBe("Runtime input value")
    t->expect(text.textContent->Null.getOrThrow)->Expect.toBe("Runtime text sentinel")
    t->expect(doc.activeElement)->Expect.toBe(focused)
    t
    ->expect((win->Window.scrollX, win->Window.scrollY, scroller.scrollTop))
    ->Expect.toEqual(scroll)
    t->expect(visibilityStyle())->Expect.toEqual(style)
  }
  let selected = input.selector->Option.mapOr(doc.body->HTMLElement.asElement, query)
  let viewport = input.selector->Option.isNone && input.fullPage != Some(true)
  let rect = selected->Element.getBoundingClientRect
  let (originX, originY, width, height) = switch viewport {
  | true => (0.0, 0.0, 800.0, 600.0)
  | false => (rect.left, rect.top, rect.width, rect.height)
  }
  let samples =
    doc
    ->Document.querySelectorAll(".marker, .visible, #outside-answer")
    ->NodeList.toArray
    ->Array.filterMap(node => {
      let bounds = node->Element.getBoundingClientRect
      let x = bounds.left +. bounds.width /. 2.0 -. originX
      let y = bounds.top +. bounds.height /. 2.0 -. originY
      let included = switch viewport {
      | true => true
      | false => selected->Element.contains(node->Element.asNode)
      }
      switch included && x > 0.0 && y > 0.0 && x < width && y < height {
      | false => None
      | true =>
        let color = switch node.id {
        | "outside-answer" => (224, 144, 32)
        | "open-answer" | "nested-answer" | "peer-answer" | "below-answer" => (32, 192, 64)
        | _ => (32, 64, 224)
        }
        Some((node.id, x, y, color))
      }
    })
  t->expect(samples->Array.length > 0)->Expect.toBe(true)
  t
  ->expect(samples->Array.some(((id, _, _, _)) => id == "after-below-closed"))
  ->Expect.toBe(!viewport && input.selector != Some("#closed"))
  let verify = async () => {
    let result = switch registry {
    | false =>
      await Client__Tool__TakeScreenshot.execute(
        input, ~taskId="screenshot-test", ~toolCallId="disclosures",
      )
    | true =>
      module T = unpack(
        Client__ToolRegistry.forFramework(Wordpress).tools
        ->Array.find(tool => {
          module T = unpack(tool)
          T.name == "take_screenshot"
        })
        ->Option.getOrThrow
      )
      let registeredInput = input->S.decodeOrThrow(
        ~from=Client__Tool__TakeScreenshot.inputSchema, ~to=T.inputSchema,
      )
      await T.execute(registeredInput, ~taskId="screenshot-test", ~toolCallId="registered-disclosures")
    }
    assertLiveState()
    await settle(win)
    assertLiveState()
    let content = result->S.decodeOrThrow(
      ~from=MCP.CallToolResult.schema,
      ~to=S.object(s => s.field("content", ContentBlock.arraySchema)),
    )
    let image = Client__ImageLimits.makeImage()
    image.src = switch content {
    | [ImageContent({data, mimeType: "image/jpeg"})] => `data:image/jpeg;base64,${data}`
    | _ => failwith("Screenshot must return a real JPEG MCP image")
    }
    await image->HTMLImageElement.decode
    let scale = image.naturalWidth->Int.toFloat /. width
    let expectedScale = switch viewport {
    | true => 1.0
    | false =>
      Client__ImageLimits.computeScale(selected, Client__ImageLimits.conservative.maxDimension) *.
      Window.current->Window.devicePixelRatio
    }
    t->expect(Math.abs(scale -. expectedScale) < 0.01)->Expect.toBe(true)
    t
    ->expect(Math.abs(image.naturalHeight->Int.toFloat -. height *. scale) <= 2.0)
    ->Expect.toBe(true)
    let canvas = DomGlobal.document->Document.createCanvasElement
    canvas.width = image.naturalWidth
    canvas.height = image.naturalHeight
    let ctx = canvas->HTMLCanvasElement.getContext2D
    ctx->CanvasRenderingContext2D.drawImage(~image, ~dx=0.0, ~dy=0.0)
    samples->Array.forEach(((id, x, y, (r, g, b))) => {
      let pixel = ctx->CanvasRenderingContext2D.getImageData(
        ~sx=(x *. scale)->Float.toInt, ~sy=(y *. scale)->Float.toInt, ~sw=1, ~sh=1,
      )
      [r, g, b]->Array.forEachWithIndex((expected, index) => {
        let actual = pixel.data->TypedArray.get(index)->Option.getOrThrow
        t
        ->expect((id, index, Math.abs((actual - expected)->Int.toFloat) <= 35.0))
        ->Expect.toEqual((id, index, true))
      })
    })
    let pixels = ctx->CanvasRenderingContext2D.getImageData(
      ~sx=0, ~sy=0, ~sw=canvas.width, ~sh=canvas.height,
    )
    let closedAnswerPixels = ref(0)
    let outsideAnswerPixels = ref(0)
    for index in 0 to canvas.width * canvas.height - 1 {
      let channel = offset => pixels.data->TypedArray.get(index * 4 + offset)->Option.getOrThrow
      switch channel(0) > 170 && channel(1) < 80 && channel(2) < 80 {
      | true => closedAnswerPixels := closedAnswerPixels.contents + 1
      | false => ()
      }
      switch channel(0) > 170 && channel(1) > 100 && channel(1) < 180 && channel(2) < 80 {
      | true => outsideAnswerPixels := outsideAnswerPixels.contents + 1
      | false => ()
      }
    }
    t->expect(closedAnswerPixels.contents)->Expect.toBe(0)
    t
    ->expect(outsideAnswerPixels.contents > 0)
    ->Expect.toBe(!viewport && input.selector->Option.isNone)
  }
  await verify()->Promise.finally(() => {
    observer->MutationObserver.disconnect
    details->Array.forEach(((node, _, _, _)) =>
      node->Element.removeEventListener(Toggle, onToggle)
    )
  })
}

let disclosureCases: array<(string, Client__Tool__TakeScreenshot.input, bool)> = [
  ("default viewport", {selector: None, fullPage: None}, false),
  ("explicit viewport", {selector: None, fullPage: Some(false)}, false),
  ("full page", {selector: None, fullPage: Some(true)}, false),
  ("container selector", {selector: Some("#target"), fullPage: None}, false),
  ("closed details selector", {selector: Some("#closed"), fullPage: None}, false),
  ("registered full page", {selector: None, fullPage: Some(true)}, true),
]

disclosureCases->Array.forEach(((mode, input, registry)) =>
  testAsync(`disclosure image and live state: ${mode}`, async t =>
    await checkDisclosures(t, input, ~registry)
  )
)
