// Lighthouse tool - runs Google Lighthouse audits on URLs
// Returns scores and top issues for performance, accessibility, best-practices, and SEO

module ChromeLauncher = FrontmanCore__ChromeLauncher
module ExnUtils = FrontmanCore__ExnUtils
module Lighthouse = FrontmanBindings.Lighthouse
module LighthouseRunner = FrontmanCore__Lighthouse
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool

let name = Tool.ToolNames.lighthouse
let visibleToAgent = true
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

// --- Input/Output Types ---

type preset =
  | @as("desktop") Desktop
  | @as("mobile") Mobile

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

// Element-level detail extracted from a Lighthouse audit's `details.items`.
// Provides the LLM with actionable information to locate and fix specific issues.
@schema
type elementDetail = {
  selector: option<string>,
  snippet: option<string>,
  nodeLabel: option<string>,
  explanation: option<string>,
  url: option<string>,
  sourceLocation: option<string>,
}

@schema
type auditIssue = {
  id: string,
  title: string,
  description: string,
  score: float,
  displayValue: option<string>,
  elements: array<elementDetail>,
}

@schema
type categoryResult = {
  id: string,
  title: string,
  score: int,
  topIssues: array<auditIssue>,
}

@schema
type output = {
  url: string,
  fetchTime: string,
  categories: array<categoryResult>,
  overallScore: int,
  warnings: array<string>,
}

// --- Implementation ---

// Categories to audit
let categoryIds = ["performance", "accessibility", "best-practices", "seo"]

// Max number of element details to include per audit issue
let maxElementsPerIssue = 3

// Manual JSON parsing below: Lighthouse `details` is typed as `option<JSON.t>` because the
// upstream schema is polymorphic (table, opportunity, node, list, etc.) and impractical to
// model as a single Sury schema. See the binding comment in Lighthouse.res:15-18.
let getStr = (dict: Dict.t<JSON.t>, key: string): option<string> =>
  dict->Dict.get(key)->Option.flatMap(JSON.Decode.string)

// Extract a node value (selector, snippet, nodeLabel, explanation) from a details item.
// Lighthouse items can have a "node" sub-object (accessibility audits) or be
// a node object directly.
let extractNodeDetail = (itemDict: Dict.t<JSON.t>): option<elementDetail> => {
  // Try nested "node" field first (e.g. accessibility table items)
  let nodeDict = switch itemDict->Dict.get("node")->Option.flatMap(JSON.Decode.object) {
  | Some(n) => Some(n)
  | None =>
    // Item itself might be a node (type: "node")
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

    // Only include if we have at least one useful field
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

// Extract a source location from a details item
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

// Extract an opportunity/resource item (url, wastedBytes, wastedMs)
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

// Extract actionable element details from a Lighthouse audit's details field.
// Handles table, opportunity, and list detail types.
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
        // Try node detail first (accessibility), then resource detail (performance)
        switch extractNodeDetail(itemDict) {
        | Some(_) as result => result
        | None => extractResourceDetail(itemDict)
        }
      }
    })
    ->Array.slice(~start=0, ~end=maxElementsPerIssue)
  }
}

// Extract top N failing audits from a category
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
    // Safe: the filter above guarantees score is Some
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

// Process LHR into our output format
let processLhr = (lhr: Lighthouse.lhr): output => {
  let categories =
    categoryIds
    ->Array.filterMap(id => lhr.categories->Dict.get(id))
    ->Array.map(category => {
      // Our requested categories (performance, accessibility, best-practices, seo) should
      // always produce a score. A null here means something unexpected happened upstream.
      let score = Float.toInt(Math.round(category.score->Nullable.toOption->Option.getOrThrow *. 100.0))
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

// Run Lighthouse with a launched Chrome instance, ensuring Chrome is killed regardless of outcome.
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

let execute = async (_ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let preset = input.preset->Option.getOr(Desktop)

  try {
    let chrome = await ChromeLauncher.launch({
      chromeFlags: [
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--disable-dev-shm-usage",
      ],
    })

    await runLighthouse(~chrome, ~url=input.url, ~preset)
  } catch {
  | exn =>
    Error(`Failed to launch Chrome: ${ExnUtils.message(exn)}. Make sure Chrome is installed on the system.`)
  }
}
