// Bindings for Google Lighthouse
// https://github.com/GoogleChrome/lighthouse

// --- Result Types ---

// Audit result from Lighthouse
type auditResult = {
  id: string,
  title: string,
  description: string,
  score: Nullable.t<float>,
  scoreDisplayMode: string,
  displayValue: option<string>,
  numericValue: option<float>,
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
