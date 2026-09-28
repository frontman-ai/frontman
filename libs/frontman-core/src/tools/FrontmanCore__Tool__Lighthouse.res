module ChromeLauncher = FrontmanCore__ChromeLauncher
module ExnUtils = FrontmanCore__ExnUtils
module Lighthouse = FrontmanBindings.Lighthouse
module LighthouseRunner = FrontmanCore__Lighthouse
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let name = Tool.ToolNames.lighthouse
let access = Tool.Read
let description = `Runs a Lighthouse audit on a URL to analyze performance, accessibility, best practices, and SEO.

WHEN TO USE THIS TOOL:
- After making changes that might affect page load performance
- When implementing new UI components to check accessibility
- Before deploying to verify web best practices
- To diagnose why a page feels slow

PARAMETERS:
- url (required): The full URL to audit (e.g., "http://localhost:3000/")
- preset (optional): "desktop" (default) or "mobile" for mobile emulation
  IMPORTANT: Check the current_page context for device_emulation - if a mobile device is being emulated (e.g., iPhone, Pixel), use preset: "mobile" to match the user's testing context.

OUTPUT:
Returns scores (0-100) for each category plus the top 3 worst issues per category.
Higher scores are better. Each issue includes:
- A description of the problem
- Specific offending elements with CSS selectors, HTML snippets, and source locations when available
Use the selectors and snippets to locate the exact elements that need fixing.

IMPORTANT - ITERATIVE FIXING:
Only the 3 worst-scoring issues per category are returned. Fixing these may reveal additional issues that were previously ranked lower. After making fixes, re-run the lighthouse audit to check for newly surfaced issues and verify improvements. Repeat until scores are satisfactory.

LIMITATIONS:
- Requires Chrome to be installed on the system
- Takes 15-30 seconds to complete
- Results can vary between runs (±5 points is normal)
- URL must be accessible from the machine running the audit`

type preset =
  | @as("desktop") Desktop
  | @as("mobile") Mobile

@@live
let presetSchema = S.union([S.literal(Desktop), S.literal(Mobile)])

let presetToString = preset =>
  switch preset {
  | Desktop => "desktop"
  | Mobile => "mobile"
  }

@schema
type input = {
  url: string,
  @s.default(Desktop) @s.matches(S.option(presetSchema))
  preset?: preset,
}

@schema
type elementDetail = {
  selector: option<string>,
  snippet: option<string>,
  nodeLabel: option<string>,
  explanation: option<string>,
  url: option<string>,
  @live
  sourceLocation: option<string>,
}

@schema
type auditIssue = {
  id: string,
  @live
  title: string,
  @live
  description: string,
  score: float,
  @live
  displayValue: option<string>,
  elements: array<elementDetail>,
}

@schema
type categoryResult = {
  id: string,
  @live
  title: string,
  score: int,
  @live
  topIssues: array<auditIssue>,
}

@schema
type output = {
  url: string,
  @live
  fetchTime: string,
  categories: array<categoryResult>,
  overallScore: int,
  @live
  warnings: array<string>,
}

let (visibleToAgent, outputJsonSchema) = (true, Some(outputSchema->S.toJSONSchema))

let categoryIds = ["performance", "accessibility", "best-practices", "seo"]

let maxElementsPerIssue = 3

let getStr = (dict: Dict.t<JSON.t>, key: string): option<string> =>
  dict->Dict.get(key)->Option.flatMap(JSON.Decode.string)

let extractNodeDetail = (itemDict: Dict.t<JSON.t>): option<elementDetail> => {
  let nodeDict = switch itemDict->Dict.get("node")->Option.flatMap(JSON.Decode.object) {
  | Some(n) => Some(n)
  | None =>
    switch getStr(itemDict, "type") {
    | Some("node") => Some(itemDict)
    | _ => None
    }
  }

  switch nodeDict {
  | Some(nd) =>
    let selector = getStr(nd, "selector")
    let snippet = getStr(nd, "snippet")
    let nodeLabel = getStr(nd, "nodeLabel")
    let explanation = getStr(nd, "explanation")

    switch (selector, snippet) {
    | (None, None) => None
    | _ =>
      Some({
        selector,
        snippet,
        nodeLabel,
        explanation,
        url: None,
        sourceLocation: None,
      })
    }
  | None => None
  }
}

let extractSourceLocation = (itemDict: Dict.t<JSON.t>): option<string> => {
  switch itemDict->Dict.get("source")->Option.flatMap(JSON.Decode.object) {
  | Some(sourceDict) =>
    switch getStr(sourceDict, "url") {
    | Some(url) =>
      let line =
        sourceDict->Dict.get("line")->Option.flatMap(JSON.Decode.float)->Option.map(Float.toInt)
      let col =
        sourceDict
        ->Dict.get("column")
        ->Option.flatMap(JSON.Decode.float)
        ->Option.map(Float.toInt)
      switch (line, col) {
      | (Some(l), Some(c)) => Some(`${url}:${Int.toString(l)}:${Int.toString(c)}`)
      | (Some(l), None) => Some(`${url}:${Int.toString(l)}`)
      | _ => Some(url)
      }
    | None => None
    }
  | None => None
  }
}

let extractResourceDetail = (itemDict: Dict.t<JSON.t>): option<elementDetail> => {
  let url = getStr(itemDict, "url")
  let sourceLocation = extractSourceLocation(itemDict)

  switch (url, sourceLocation) {
  | (None, None) => None
  | _ =>
    Some({
      selector: None,
      snippet: None,
      nodeLabel: None,
      explanation: None,
      url,
      sourceLocation,
    })
  }
}

let extractElements = (details: option<JSON.t>): array<elementDetail> => {
  switch details->Option.flatMap(JSON.Decode.object) {
  | None => []
  | Some(detailsDict) =>
    let items = switch detailsDict->Dict.get("items")->Option.flatMap(JSON.Decode.array) {
    | Some(arr) => arr
    | None => []
    }

    items
    ->Array.filterMap(item => {
      switch JSON.Decode.object(item) {
      | None => None
      | Some(itemDict) =>
        switch extractNodeDetail(itemDict) {
        | Some(_) as result => result
        | None => extractResourceDetail(itemDict)
        }
      }
    })
    ->Array.slice(~start=0, ~end=maxElementsPerIssue)
  }
}

let getTopIssues = (
  ~category: Lighthouse.category,
  ~audits: Dict.t<Lighthouse.auditResult>,
  ~maxIssues: int,
): array<auditIssue> => {
  category.auditRefs
  ->Array.filterMap(ref => audits->Dict.get(ref.id))
  ->Array.filter(audit => {
    switch (audit.scoreDisplayMode, audit.score->Nullable.toOption) {
    | (Binary | Numeric | MetricSavings, Some(score)) => score < 1.0
    | _ => false
    }
  })
  ->Array.toSorted((a, b) => {
    let scoreA = a.score->Nullable.toOption->Option.getOrThrow
    let scoreB = b.score->Nullable.toOption->Option.getOrThrow
    scoreA -. scoreB
  })
  ->Array.slice(~start=0, ~end=maxIssues)
  ->Array.map(audit => {
    id: audit.id,
    title: audit.title,
    description: audit.description,
    score: audit.score->Nullable.toOption->Option.getOrThrow,
    displayValue: audit.displayValue,
    elements: extractElements(audit.details),
  })
}

let processLhr = (lhr: Lighthouse.lhr): output => {
  let categories =
    categoryIds
    ->Array.filterMap(id => lhr.categories->Dict.get(id))
    ->Array.map(category => {
      let score = Float.toInt(
        Math.round(category.score->Nullable.toOption->Option.getOrThrow *. 100.0),
      )
      let topIssues = getTopIssues(~category, ~audits=lhr.audits, ~maxIssues=3)
      {
        id: category.id,
        title: category.title,
        score,
        topIssues,
      }
    })

  let totalScore = categories->Array.reduce(0, (acc, cat) => acc + cat.score)
  let overallScore = switch categories->Array.length {
  | 0 => 0
  | len => totalScore / len
  }

  {
    url: lhr.finalDisplayedUrl,
    fetchTime: lhr.fetchTime,
    categories,
    overallScore,
    warnings: lhr.runWarnings,
  }
}

let runLighthouse = async (
  ~chrome: ChromeLauncher.launchedChrome,
  ~url: string,
  ~preset: preset,
): result<output, string> => {
  let port = chrome->ChromeLauncher.getPort
  let formFactor = presetToString(preset)

  let flags: Lighthouse.flags = {
    port,
    output: "json",
    logLevel: "error",
    onlyCategories: categoryIds,
    formFactor,
    screenEmulation: {
      disabled: switch preset {
      | Desktop => true
      | Mobile => false
      },
    },
    throttlingMethod: "simulate",
  }

  let result = try {
    let runnerResult = await LighthouseRunner.run(url, flags)

    switch runnerResult->Nullable.toOption {
    | Some(r) => Ok(processLhr(r.lhr))
    | None => Error("Lighthouse returned no results. The URL may be unreachable.")
    }
  } catch {
  | exn => Error(`Lighthouse audit failed: ${ExnUtils.message(exn)}`)
  }

  await ChromeLauncher.killSafely(chrome)
  result
}

let execute = async (
  _ctx: Tool.serverExecutionContext,
  input: input,
): Tool.MCP.CallToolResult.t => {
  let preset = input.preset->Option.getOr(Desktop)

  try {
    let chrome = await ChromeLauncher.launch({
      chromeFlags: ["--headless", "--disable-gpu", "--no-sandbox", "--disable-dev-shm-usage"],
    })

    switch await runLighthouse(~chrome, ~url=input.url, ~preset) {
    | Ok(output) => Tool.structuredResult(output, outputSchema)
    | Error(msg) => Tool.MCP.CallToolResult.makeError(msg)
    }
  } catch {
  | exn =>
    Tool.MCP.CallToolResult.makeError(
      `Failed to launch Chrome: ${ExnUtils.message(
          exn,
        )}. Make sure Chrome is installed on the system.`,
    )
  }
}
