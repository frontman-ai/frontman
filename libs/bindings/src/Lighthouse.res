// Bindings for Google Lighthouse
// https://github.com/GoogleChrome/lighthouse

// --- Result Types ---

// Score display modes used by Lighthouse audits.
// See: https://github.com/GoogleChrome/lighthouse/blob/main/types/lhr/audit-result.d.ts
type scoreDisplayMode =
  | @as("numeric") Numeric
  | @as("binary") Binary
  | @as("informative") Informative
  | @as("notApplicable") NotApplicable
  | @as("manual") Manual
  | @as("error") Error
  | @as("metricSavings") MetricSavings

// Audit result from Lighthouse
type auditResult = {
  id: string,
  title: string,
  description: string,
  score: Nullable.t<float>,
  scoreDisplayMode: scoreDisplayMode,
  displayValue: option<string>,
  numericValue: option<float>,
  // details is a polymorphic union (table, opportunity, node, etc.)
  // kept as JSON.t because the full type is impractical to model in ReScript.
  // Consumers should extract actionable fields (selectors, snippets, source locations) manually.
  details: option<JSON.t>,
}

// Category with score and audit references
type auditRef = {
  id: string,
  weight: float,
}

type category = {
  id: string,
  title: string,
  description: option<string>,
  score: Nullable.t<float>,
  auditRefs: array<auditRef>,
}

// The main Lighthouse Result (LHR) object
type lhr = {
  lighthouseVersion: string,
  fetchTime: string,
  requestedUrl: option<string>,
  finalDisplayedUrl: string,
  audits: Dict.t<auditResult>,
  categories: Dict.t<category>,
  runWarnings: array<string>,
}

// Runner result returned by lighthouse()
type runnerResult = {
  lhr: lhr,
  report: string,
}

// --- Lighthouse Options ---

type screenEmulation = {disabled: bool}

type flags = {
  port?: int,
  output?: string,
  logLevel?: string,
  onlyCategories?: array<string>,
  formFactor?: string,
  screenEmulation?: screenEmulation,
  throttlingMethod?: string,
}

// --- Main API ---

// Run lighthouse on a URL
// Loaded lazily at runtime to avoid bundler static resolution issues.
let run: (string, flags) => promise<Nullable.t<runnerResult>> = %raw(`
  (url, flags) =>
    import("node:module")
      .then(({createRequire}) => {
        const req = createRequire(import.meta.url)
        try {
          const mod = req("lighthouse")
          const lighthouse = mod.default ?? mod
          return lighthouse(url, flags)
        } catch (e) {
          if (e.code === "MODULE_NOT_FOUND") {
            throw new Error("lighthouse is not installed. Run: npm install lighthouse")
          }
          throw e
        }
      })
`)
