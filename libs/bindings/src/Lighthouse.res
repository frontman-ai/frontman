type scoreDisplayMode =
  | @as("numeric") Numeric
  | @as("binary") Binary
  | @as("informative") Informative
  | @as("notApplicable") NotApplicable
  | @as("manual") Manual
  | @as("error") Error
  | @as("metricSavings") MetricSavings

type auditResult = {
  id: string,
  title: string,
  description: string,
  score: Nullable.t<float>,
  scoreDisplayMode: scoreDisplayMode,
  displayValue: option<string>,
  numericValue: option<float>,
  details: option<JSON.t>,
}

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

type lhr = {
  lighthouseVersion: string,
  fetchTime: string,
  requestedUrl: option<string>,
  finalDisplayedUrl: string,
  audits: Dict.t<auditResult>,
  categories: Dict.t<category>,
  runWarnings: array<string>,
}

type runnerResult = {
  lhr: lhr,
  report: string,
}

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
