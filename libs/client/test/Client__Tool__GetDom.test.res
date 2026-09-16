open Vitest

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module GetDom = Client__Tool__GetDom
module Persistence = FrontmanAiAstroBrowser.FrontmanAstroBrowser__Persistence
module Navigation = FrontmanAiAstroBrowser.FrontmanAstroBrowser__Navigation

@set
external setNavigation: (WebAPI.DomTypes.window, option<Navigation.state>) => unit =
  "__frontman_astro_navigation__"

type previewModule
type spy
@module external previewModule: previewModule = "../src/tools/Client__Tool__PreviewContext.res.mjs"
@module("vitest") @scope("vi") external spyOn: (previewModule, @as("get") _) => spy = "spyOn"
@send external mockReturnValue: (spy, option<Tool.previewContext>) => unit = "mockReturnValue"
@module("vitest") @scope("vi") external resetAllMocks: unit => unit = "resetAllMocks"
@send
external createIframe: (
  WebAPI.DomTypes.document,
  @as("iframe") _,
) => WebAPI.DomTypes.htmliFrameElement = "createElement"

@schema
type page = {
  url: string,
  html: string,
  astro_client_routing: option<string>,
  astro_persistence: option<Persistence.t>,
  astro_navigation: option<Navigation.t>,
}
@schema
type textContent = {text: string}
@schema
type response = {
  isError: option<bool>,
  structuredContent: option<page>,
  content: array<textContent>,
}

let get = spyOn(previewModule)
afterEach(() => {
  WebAPI.DomGlobal.document.body.innerHTML = ""
  resetAllMocks()
  setNavigation(WebAPI.DomGlobal.window, None)
})

let showPage = (enabled, ~text="Content", ~html=?) => {
  let frame = WebAPI.DomGlobal.document->createIframe
  frame->WebAPI.HTMLIFrameElement.setAttribute(
    ~qualifiedName="src",
    ~value=`https://preview.test/${Bool.toString(enabled)}`,
  )
  WebAPI.DomGlobal.document.body
  ->WebAPI.HTMLElement.appendChild(frame->WebAPI.HTMLIFrameElement.asNode)
  ->ignore
  let doc = frame->WebAPI.HTMLIFrameElement.contentDocument->Option.getOrThrow
  let win = frame->WebAPI.HTMLIFrameElement.contentWindow->Option.getOrThrow
  let marker = switch enabled {
  | true => "<meta name=\"astro-view-transitions-enabled\">"
  | false => ""
  }
  let content = html->Option.getOr(`<main id="page"><span>${text}</span></main>`)
  doc->WebAPI.Document.write(`<html><head>${marker}</head><body>${content}</body></html>`)
  doc->WebAPI.Document.close
  get->mockReturnValue(Some({doc, win}))
}

let execute = async (framework, input: GetDom.input) => {
  module T = unpack(
    Client__ToolRegistry.forFramework(framework).tools
    ->Array.find(tool => {
      module T = unpack(tool)
      T.name == GetDom.name
    })
    ->Option.getOrThrow
  )
  let input =
    input->S.decodeOrThrow(~from=GetDom.inputSchema, ~to=S.json)->S.parseOrThrow(~to=T.inputSchema)
  let result = await T.execute(input, ~taskId="task", ~toolCallId="call")
  result
  ->S.decodeOrThrow(~from=Tool.MCP.CallToolResult.schema, ~to=S.json)
  ->S.parseOrThrow(~to=responseSchema)
}

let input: GetDom.input = {
  selector: "#page",
  mode: None,
  maxDepth: None,
  maxNodes: None,
  pierceShadowDom: None,
}

[("simplified", #simplified), ("full", #full)]->Array.forEach(((label, mode)) => {
  testAsync(`reads fresh preview data in ${label} mode`, async t => {
    for index in 0 to 1 {
      let (enabled, routing) =
        [(true, "enabled"), (false, "disabled")]
        ->Array.get(index)
        ->Option.getOrThrow
      showPage(enabled)
      let response = await execute(Astro, {...input, mode: Some(mode)})
      let page = response.structuredContent->Option.getOrThrow
      t->expect(response.isError)->Expect.toEqual(None)
      t->expect(page.url)->Expect.toBe(`https://preview.test/${Bool.toString(enabled)}`)
      t->expect(page.html->String.includes("Content"))->Expect.toBe(true)
      t->expect(page.astro_client_routing)->Expect.toEqual(Some(routing))
    }
  })
})

[#simplified, #full]->Array.forEach(mode => {
  testAsync("reads fresh navigation evidence only from the preview window", async t => {
    showPage(true)
    let {win} = Client__Tool__PreviewContext.get()->Option.getOrThrow
    let from = "https://preview.test/start"
    let to = "https://preview.test/destination"
    setNavigation(
      WebAPI.DomGlobal.window,
      Some({lastNavigation: Some({from, to, phase: PageLoad})}),
    )
    let absent = await execute(Astro, {...input, mode: Some(mode)})
    let page = absent.structuredContent->Option.getOrThrow
    t->expect(page.astro_client_routing)->Expect.toEqual(Some("enabled"))
    t->expect(page.astro_navigation)->Expect.toEqual(Some(Navigation.Unavailable))

    setNavigation(win, Some({lastNavigation: None}))
    let empty = await execute(Astro, {...input, mode: Some(mode)})
    t
    ->expect((empty.structuredContent->Option.getOrThrow).astro_navigation)
    ->Expect.toEqual(Some(Navigation.NotObserved))

    let phases = [
      Navigation.BeforePreparation,
      AfterPreparation,
      BeforeSwap,
      AfterSwap,
      PageLoad,
      HashChange,
    ]
    for index in 0 to phases->Array.length - 1 {
      let phase = phases->Array.get(index)->Option.getOrThrow
      let destination = switch phase {
      | HashChange => to ++ "#section"
      | BeforePreparation | AfterPreparation | BeforeSwap | AfterSwap | PageLoad => to
      }
      setNavigation(win, Some({lastNavigation: Some({from, to: destination, phase})}))
      let response = await execute(Astro, {...input, mode: Some(mode)})
      let page = response.structuredContent->Option.getOrThrow
      t
      ->expect(page.astro_navigation)
      ->Expect.toEqual(Some(Navigation.Observed({from, to: destination, phase})))
      let text = (response.content->Array.get(0)->Option.getOrThrow).text
      let textPage = S.decodeOrThrow(text, ~from=S.jsonString, ~to=pageSchema)
      t->expect(textPage.astro_navigation)->Expect.toEqual(page.astro_navigation)
    }

    showPage(false)
    let reloaded = await execute(Astro, {...input, mode: Some(mode)})
    let page = reloaded.structuredContent->Option.getOrThrow
    t->expect(page.astro_client_routing)->Expect.toEqual(Some("disabled"))
    t->expect(page.astro_navigation)->Expect.toEqual(Some(Navigation.Unavailable))
  })
})

[#simplified, #full]->Array.forEach(mode => {
  testAsync("shows direct markers and ancestors outside the inspected subtree", async t => {
    showPage(
      true,
      ~html="<main id=\"layout\" data-astro-transition-persist=\"outer\"><section id=\"player\" data-astro-transition-persist=\"audio\"><div><button id=\"page\" data-astro-transition-persist=\"control\"><span data-astro-transition-persist=\"label\">Play</span></button></div></section></main>",
    )
    for index in 0 to 1 {
      let selector = ["#page", "//button[@id='page']"]->Array.get(index)->Option.getOrThrow
      let response = await execute(Astro, {...input, selector, mode: Some(mode)})
      let page = response.structuredContent->Option.getOrThrow
      t
      ->expect(page.html->String.includes("data-astro-transition-persist=\"control\""))
      ->Expect.toBe(true)
      t
      ->expect(page.html->String.includes("data-astro-transition-persist=\"label\""))
      ->Expect.toBe(true)
      let persistence = page.astro_persistence->Option.getOrThrow
      t->expect(persistence.truncated)->Expect.toBe(false)
      t->expect(persistence.ancestors->Array.length)->Expect.toBe(2)
      let nearest = persistence.ancestors->Array.get(0)->Option.getOrThrow
      let farthest = persistence.ancestors->Array.get(1)->Option.getOrThrow
      t
      ->expect(nearest->String.includes("data-astro-transition-persist=\"audio\""))
      ->Expect.toBe(true)
      t->expect(nearest->String.includes("selector=\"#player\""))->Expect.toBe(true)
      t->expect(farthest->String.includes("selector=\"#layout\""))->Expect.toBe(true)
    }
    showPage(false)
    let response = await execute(Astro, {...input, mode: Some(mode)})
    let persistence =
      (response.structuredContent->Option.getOrThrow).astro_persistence->Option.getOrThrow
    t->expect(persistence.ancestors)->Expect.toEqual([])
    t->expect(persistence.truncated)->Expect.toBe(false)
  })
})

testAsync("reads current runtime markers, including empty keys, not source directives", async t => {
  showPage(
    false,
    ~html="<main id=\"boundary\" transition:persist=\"audio\"><div id=\"page\" data-astro-transition-persist=\"\"></div></main>",
  )
  let {doc} = Client__Tool__PreviewContext.get()->Option.getOrThrow
  let boundary = doc->WebAPI.Document.querySelector("#boundary")->Null.toOption->Option.getOrThrow
  for index in 0 to 2 {
    switch index {
    | 1 =>
      boundary->WebAPI.Element.setAttribute(~qualifiedName=Persistence.markerAttribute, ~value="")
    | _ => boundary->WebAPI.Element.removeAttribute(Persistence.markerAttribute)
    }
    let response = await execute(Astro, input)
    let page = response.structuredContent->Option.getOrThrow
    t->expect(page.astro_client_routing)->Expect.toEqual(Some("disabled"))
    t->expect(page.html->String.includes("data-astro-transition-persist=\"\""))->Expect.toBe(true)
    let persistence = page.astro_persistence->Option.getOrThrow
    t->expect(persistence.truncated)->Expect.toBe(false)
    t->expect(persistence.ancestors->Array.length)->Expect.toBe(index == 1 ? 1 : 0)
    switch persistence.ancestors->Array.get(0) {
    | Some(ancestor) =>
      t->expect(ancestor->String.includes("data-astro-transition-persist=\"\""))->Expect.toBe(true)
    | None => ()
    }
  }
})

testAsync(
  "reuses shadow-path resolution and scopes ancestor evidence to that DOM tree",
  async t => {
    showPage(true, ~html="<div id=\"page\" data-astro-transition-persist=\"host\"></div>")
    let {doc} = Client__Tool__PreviewContext.get()->Option.getOrThrow
    let host = doc->WebAPI.Document.querySelector("#page")->Null.toOption->Option.getOrThrow
    let shadow = host->WebAPI.Element.attachShadow({mode: Open})
    shadow.innerHTML = "<section data-astro-transition-persist=\"inside-shadow\"><button data-astro-transition-persist=\"button\">Play</button></section>"
    let response = await execute(Astro, {...input, selector: "#page >>> 1/1"})
    let page = response.structuredContent->Option.getOrThrow
    t
    ->expect(page.html->String.includes("data-astro-transition-persist=\"button\""))
    ->Expect.toBe(true)
    let ancestors = (page.astro_persistence->Option.getOrThrow).ancestors
    t->expect(ancestors->Array.length)->Expect.toBe(1)
    t
    ->expect(
      ancestors
      ->Array.get(0)
      ->Option.getOrThrow
      ->String.includes("data-astro-transition-persist=\"inside-shadow\""),
    )
    ->Expect.toBe(true)
  },
)

[Client__RuntimeConfig.Nextjs, Vite, Wordpress]->Array.forEach(framework => {
  testAsync("keeps persistence enrichment out of non-Astro inspection", async t => {
    showPage(
      true,
      ~html="<main data-astro-transition-persist=\"outer\"><div id=\"page\" data-astro-transition-persist=\"inner\"></div></main>",
    )
    let response = await execute(framework, input)
    let page = response.structuredContent->Option.getOrThrow
    t->expect(page.html->String.includes("data-astro-transition-persist"))->Expect.toBe(false)
    t->expect(page.astro_persistence)->Expect.toEqual(None)
    t->expect(page.astro_navigation)->Expect.toEqual(None)
  })
})

[Client__RuntimeConfig.Astro, Nextjs]->Array.forEach(framework => {
  testAsync(
    `returns MCP errors with narrowing guidance for ${Client__RuntimeConfig.frameworkIdToString(
        framework,
      )}`,
    async t => {
      showPage(true, ~text="x"->String.repeat(15001))
      let cases = [
        ("#missing", None, "No element found"),
        ("#page", Some(1), "Subtree too large"),
        ("#page", None, "HTML too large"),
        ("#page", None, "Preview frame not available"),
      ]
      for index in 0 to 3 {
        switch index {
        | 3 => get->mockReturnValue(None)
        | _ => ()
        }
        let (selector, maxNodes, message) = cases->Array.get(index)->Option.getOrThrow
        let response = await execute(framework, {...input, selector, maxNodes, mode: Some(#full)})
        let text = (response.content->Array.get(0)->Option.getOrThrow).text
        t->expect(response.isError)->Expect.toEqual(Some(true))
        t->expect(response.structuredContent)->Expect.toEqual(None)
        t->expect(text->String.includes(message))->Expect.toBe(true)
        switch index {
        | 1 | 2 => t->expect(text->String.includes("Target a child selector"))->Expect.toBe(true)
        | _ => ()
        }
      }
    },
  )
})
