open Vitest
open Test__Mocks
module Reducer = Client__Task__Reducer
module Dom = Test__Dom
module Source = Client__SourceContext
module Snapdom = FrontmanBindings.Bindings__Snapdom
open Snapdom

vi->mockModule("@medv/finder", () =>
  {
    "finder": vi->fn((
      ~element as _: WebAPI.DomTypes.element,
      ~options as _: FrontmanBindings.Bindings__Finder.finderOptions,
    ) => "#submit"),
  }
)
vi->mockModule("@zumer/snapdom", () =>
  {
    "snapdom": vi->fn((_element: WebAPI.DomTypes.element): Promise.t<Snapdom.captureResult> =>
      Promise.resolve({
        toCanvas: _ => JsError.throwWithMessage("Unexpected canvas request"),
        toJpg: _ => Promise.resolve({src: "data:image/jpeg;base64,abc123"}),
      })
    ),
  }
)
vi->mockModule("../src/Client__SourceDetection.res.mjs", () =>
  {
    "getElementSourceLocation": vi->fn((
      ~element as _: WebAPI.DomTypes.element,
      ~window as _: WebAPI.DomTypes.window,
    ): Promise.t<option<Source.t>> => Promise.resolve(None)),
  }
)
vi->mockModule("../src/Client__SourceLocationResolver.res.mjs", () =>
  {
    "resolve": vi->fn(async (_context: Source.t): result<Client__Types.SourceLocation.t, string> =>
      JsError.throwWithMessage("Resolver not arranged")
    ),
  }
)

@module
external finderModule: {
  "finder": (
    ~element: WebAPI.DomTypes.element,
    ~options: FrontmanBindings.Bindings__Finder.finderOptions,
  ) => string,
} = "@medv/finder"
@module
external captureModule: {"snapdom": WebAPI.DomTypes.element => Promise.t<Snapdom.captureResult>} =
  "@zumer/snapdom"
let finder = vi->mocked(finderModule["finder"])
let capture = vi->mocked(captureModule["snapdom"])
let detect = vi->mocked(Client__SourceDetection.getElementSourceLocation)
let resolve = vi->mocked(Client__SourceLocationResolver.resolve)
let calls = ref(0)
let ordinary: Source.location = {
  componentName: Some("Counter"),
  tagName: Some("button"),
  file: "src/Counter.vue",
  line: 8,
  column: 1,
  componentProps: Some(Dict.fromArray([("initial", JSON.Encode.int(1))])),
}
let virtual: Source.t = {
  definition: None,
  invocations: [{...ordinary, file: "about://React/Server/file:///app/.next/server/chunk.js"}],
}
let resolved: Client__Types.SourceLocation.t = {
  componentName: Some("Button"),
  tagName: "button",
  file: "src/Button.tsx",
  line: 42,
  column: 5,
  parent: None,
  componentProps: None,
}

beforeEach(() => {
  vi->stubGlobal("__frontmanRuntime", {"framework": "nextjs"})
  calls := 0
  Dom.html(`<div id="form-actions"><button id="submit" class="btn-submit primary">Submit "now"<span class="button-overlay"></span></button></div>`)
  finder->implementation((~element as _, ~options as _) => "#submit")
  capture->implementation(_ =>
    Promise.resolve({
      toCanvas: _ => JsError.throwWithMessage("Unexpected canvas request"),
      toJpg: _ => Promise.resolve({src: "data:image/jpeg;base64,abc123"}),
    })
  )
  detect->implementation((~element as _, ~window as _) => Promise.resolve(None))
  resolve->implementation(_ => {
    calls := calls.contents + 1
    Promise.resolve(Ok(resolved))
  })
})
afterEach(() => {
  Vi.useRealTimers()->ignore
  vi->unstubAllGlobals
})

let start = (~withWindow=false) => {
  let dispatched = ref([])
  Reducer.handleEffect(
    FetchAnnotationDetails({
      id: "ann-test-1",
      element: Dom.query("#submit"),
      document: Some(Dom.document),
      contentWindow: withWindow ? Some(WebAPI.Window.current) : None,
    }),
    ~dispatch=action => dispatched := dispatched.contents->Array.concat([action]),
    ~delegate=_ => (),
  )
  dispatched
}
let wait = async dispatched => {
  await Vi.waitFor(() =>
    switch dispatched.contents {
    | [_] => ()
    | _ => JsError.throwWithMessage("Expected one enrichment dispatch")
    }
  , ())
  dispatched.contents->Array.get(0)->Option.getOrThrow
}

type failure = Selector | Capture | Encoding | Detection

describe("FetchAnnotationDetails", _ => {
  [Client__RuntimeConfig.Astro, Nextjs, Vite, Wordpress]->Array.forEach(framework => {
    testAsync(
      `scopes persistence markers to Astro when annotating ${Client__RuntimeConfig.frameworkIdToString(
          framework,
        )}`,
      async t => {
        vi->stubGlobal(
          "__frontmanRuntime",
          {"framework": Client__RuntimeConfig.frameworkIdToString(framework)},
        )
        Dom.query("#submit")->WebAPI.Element.setAttribute(
          ~qualifiedName="data-astro-transition-persist",
          ~value="submit-action",
        )
        switch await start()->wait {
        | AnnotationDetailsResolved({elementContext}) =>
          t
          ->expect(
            elementContext
            ->Result.getOrThrow
            ->Option.getOrThrow
            ->String.includes(`data-astro-transition-persist="submit-action"`),
          )
          ->Expect.toBe(framework == Astro)
        | _ => JsError.throwWithMessage("Expected annotation details")
        }
      },
    )
  })

  testAsync("enriches context and screenshot without a source window", async t => {
    let action = await start()->wait
    switch action {
    | AnnotationDetailsResolved({
        enrichmentStatus: Enriched,
        selector,
        screenshot,
        elementContext,
        sourceLocation,
      }) =>
      t->expect(selector)->Expect.toEqual(Ok(Some("#submit")))
      t->expect(screenshot)->Expect.toEqual(Ok(Some("data:image/jpeg;base64,abc123")))
      t
      ->expect(
        elementContext
        ->Result.getOrThrow
        ->Option.getOrThrow
        ->String.includes(`selected tag="button"`),
      )
      ->Expect.toBe(true)
      t->expect(sourceLocation)->Expect.toEqual(Ok(None))
    | _ => JsError.throwWithMessage("Expected enriched annotation")
    }
  })

  testAsync("resolves virtual React context with one request", async t => {
    detect->implementation((~element as _, ~window as _) => Promise.resolve(Some(virtual)))
    let action = await start(~withWindow=true)->wait
    switch action {
    | AnnotationDetailsResolved({sourceLocation: Ok(Some(location))}) =>
      t->expect(location.file)->Expect.toBe("src/Button.tsx")
      t->expect(location.line)->Expect.toBe(42)
      t->expect(calls.contents)->Expect.toBe(1)
    | _ => JsError.throwWithMessage("Expected resolved source")
    }
  })

  testAsync("keeps structured server-resolution errors", async t => {
    detect->implementation((~element as _, ~window as _) => Promise.resolve(Some(virtual)))
    resolve->implementation(_ => Promise.resolve(Error("HTTP 422: Unprocessable Entity")))
    let action = await start(~withWindow=true)->wait
    switch action {
    | AnnotationDetailsResolved({sourceLocation}) =>
      t->expect(sourceLocation)->Expect.toEqual(Error("HTTP 422: Unprocessable Entity"))
    | _ => JsError.throwWithMessage("Expected annotation details")
    }
  })

  testAsync("uses ordinary source context without server resolution", async t => {
    detect->implementation(
      (~element as _, ~window as _) =>
        Promise.resolve(Some({Source.definition: Some(ordinary), invocations: []})),
    )
    let action = await start(~withWindow=true)->wait
    switch action {
    | AnnotationDetailsResolved({sourceLocation: Ok(Some(location))}) =>
      t->expect(location.file)->Expect.toBe("src/Counter.vue")
      t->expect(location.componentName)->Expect.toEqual(Some("Counter"))
      t->expect(location.parent)->Expect.toEqual(None)
      t->expect(calls.contents)->Expect.toBe(0)
    | _ => JsError.throwWithMessage("Expected ordinary source")
    }
  })

  [#detection, #resolution]->Array.forEach(stage => {
    testAsync(
      `times out source ${switch stage {
        | #detection => "detection"
        | #resolution => "resolution"
        }}`,
      async t => {
        Vi.useFakeTimers()->ignore
        switch stage {
        | #detection =>
          detect->implementation((~element as _, ~window as _) => Promise.make((_, _) => ()))
        | #resolution =>
          detect->implementation((~element as _, ~window as _) => Promise.resolve(Some(virtual)))
          resolve->implementation(_ => Promise.make((_, _) => ()))
        }
        let dispatched = start(~withWindow=true)
        let _ = await Vi.advanceTimersByTimeAsync(5000)
        switch dispatched.contents {
        | [AnnotationDetailsResolved({sourceLocation})] =>
          t
          ->expect(sourceLocation)
          ->Expect.toEqual(Error("Source location detection or resolution timed out"))
        | _ => JsError.throwWithMessage("Expected one timed-out annotation")
        }
      },
    )
  })

  [Selector, Capture, Encoding, Detection]->Array.forEach(failure => {
    let (name, error) = switch failure {
    | Selector => ("selector", "No unique selector found")
    | Capture => ("screenshot capture", "Canvas tainted")
    | Encoding => ("screenshot encoding", "JPEG conversion failed")
    | Detection => ("source detection", "CORS blocked source map")
    }
    testAsync(
      `preserves enrichment when ${name} fails`,
      async t => {
        switch failure {
        | Selector =>
          finder->implementation((~element as _, ~options as _) => JsError.throwWithMessage(error))
        | Capture => capture->implementation(async _ => JsError.throwWithMessage(error))
        | Encoding =>
          capture->implementation(
            _ =>
              Promise.resolve({
                toCanvas: _ => JsError.throwWithMessage("Unexpected canvas"),
                toJpg: async _ => JsError.throwWithMessage(error),
              }),
          )
        | Detection =>
          detect->implementation(
            async (~element as _, ~window as _) => JsError.throwWithMessage(error),
          )
        }
        let action = await start(~withWindow=failure === Detection)->wait
        switch action {
        | AnnotationDetailsResolved({
            enrichmentStatus: Enriched,
            selector,
            screenshot,
            sourceLocation,
          }) =>
          switch failure {
          | Selector => t->expect(selector)->Expect.toEqual(Error(error))
          | Capture | Encoding => t->expect(screenshot)->Expect.toEqual(Error(error))
          | Detection => t->expect(sourceLocation)->Expect.toEqual(Error(error))
          }
          switch (failure, selector, screenshot, sourceLocation) {
          | (Selector, _, Ok(_), Ok(_))
          | (Capture | Encoding, Ok(_), _, Ok(_))
          | (Detection, Ok(_), Ok(_), _) => ()
          | _ => JsError.throwWithMessage("Unrelated enrichment must survive")
          }
        | _ => JsError.throwWithMessage("Expected enriched annotation")
        }
      },
    )
  })

  testAsync("isolates synchronous resolver failures", async t => {
    detect->implementation((~element as _, ~window as _) => Promise.resolve(Some(virtual)))
    resolve->implementation(_ => JsError.throwWithMessage("Resolver exploded"))
    let action = await start(~withWindow=true)->wait
    switch action {
    | AnnotationDetailsResolved({
        enrichmentStatus: Enriched,
        selector: Ok(_),
        screenshot: Ok(_),
        sourceLocation,
      }) =>
      t->expect(sourceLocation)->Expect.toEqual(Error("Resolver exploded"))
    | _ => JsError.throwWithMessage("Expected isolated failure")
    }
  })
})
