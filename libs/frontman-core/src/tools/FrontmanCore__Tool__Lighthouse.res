// Lighthouse tool - runs Google Lighthouse audits on URLs
// Returns scores and top issues for performance, accessibility, best-practices, and SEO

module ChromeLauncher = FrontmanBindings.ChromeLauncher
module Lighthouse = FrontmanBindings.Lighthouse
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
Returns scores (0-100) for each category plus the top 3 issues to fix in each category.
Higher scores are better. Issues include actionable descriptions.

LIMITATIONS:
- Requires Chrome to be installed on the system
- Takes 15-30 seconds to complete
- Results can vary between runs (±5 points is normal)
- URL must be accessible from the machine running the audit`

// --- Input/Output Types ---

@schema
type input = {
  url: string,
  @s.default("desktop")
  preset?: string,
}

@schema
type auditIssue = {
  id: string,
  title: string,
  description: string,
  score: float,
  displayValue: option<string>,
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

// Extract top N failing audits from a category
let getTopIssues = (
  ~category: Lighthouse.category,
  ~audits: Dict.t<Lighthouse.auditResult>,
  ~maxIssues: int,
): array<auditIssue> => {
  category.auditRefs
  ->Array.filterMap(ref => audits->Dict.get(ref.id))
  ->Array.filter(audit => {
    switch audit.score->Nullable.toOption {
    | Some(score) =>
      (audit.scoreDisplayMode === "binary" ||
        audit.scoreDisplayMode === "numeric" ||
        audit.scoreDisplayMode === "metricSavings") && score < 1.0
    | None => false
    }
  })
  ->Array.toSorted((a, b) => {
    let scoreA = a.score->Nullable.toOption->Option.getOr(0.0)
    let scoreB = b.score->Nullable.toOption->Option.getOr(0.0)
    scoreA -. scoreB
  })
  ->Array.slice(~start=0, ~end=maxIssues)
  ->Array.map(audit => {
    id: audit.id,
    title: audit.title,
    description: audit.description,
    score: audit.score->Nullable.toOption->Option.getOr(0.0),
    displayValue: audit.displayValue,
  })
}

// Process LHR into our output format
let processLhr = (lhr: Lighthouse.lhr): output => {
  let categories =
    categoryIds
    ->Array.filterMap(id => lhr.categories->Dict.get(id))
    ->Array.map(category => {
      let score = switch category.score->Nullable.toOption {
      | Some(s) => Float.toInt(Math.round(s *. 100.0))
      | None => 0
      }
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

// Run Lighthouse with a launched Chrome instance
let runLighthouse = async (
  ~chrome: ChromeLauncher.launchedChrome,
  ~url: string,
  ~preset: string,
): result<output, string> => {
  let port = chrome->ChromeLauncher.getPort

  let flags: Lighthouse.flags = {
    port,
    output: "json",
    logLevel: "error",
    onlyCategories: categoryIds,
    formFactor: preset,
    screenEmulation: {disabled: preset === "desktop"},
    throttlingMethod: "simulate",
  }

  try {
    let runnerResult = await Lighthouse.run(url, flags)

    await ChromeLauncher.killSafely(chrome)

    switch runnerResult->Nullable.toOption {
    | Some(r) => Ok(processLhr(r.lhr))
    | None => Error("Lighthouse returned no results. The URL may be unreachable.")
    }
  } catch {
  | exn =>
    await ChromeLauncher.killSafely(chrome)

    let msg =
      exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
    Error(`Lighthouse audit failed: ${msg}`)
  }
}

let execute = async (_ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  let preset = input.preset->Option.getOr("desktop")

  switch preset {
  | "desktop" | "mobile" =>
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
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
      Error(`Failed to launch Chrome: ${msg}. Make sure Chrome is installed on the system.`)
    }

  | other => Error(`Invalid preset "${other}". Must be "desktop" or "mobile".`)
  }
}
