type errorCode = string

type error = {
  code: errorCode,
  message: string,
}

@schema
type getDomInput = {
  @s.describe(
    "CSS selector or XPath expression targeting a DOM subtree. Target the smallest subtree you need. CSS examples: '#main-content', '.hero-section', '[role=\"navigation\"]'. XPath examples: '//form', '//div[@id=\"app\"]'"
  )
  selector: string,
  @s.describe(
    "Output mode: 'simplified' (default) returns line-oriented element descriptors, 'full' returns raw outerHTML."
  )
  mode: option<[#full | #simplified]>,
  @s.describe("Maximum target subtree depth in simplified mode. Defaults to 1.")
  maxDepth: option<int>,
  @s.describe("Maximum number of element nodes to include. Defaults to 200.")
  maxNodes: option<int>,
  @s.describe("Whether simplified mode traverses open shadow DOM roots. Defaults to false.")
  pierceShadowDom: option<bool>,
}

@schema
type getDomOutput = {
  @s.describe("Whether the DOM query succeeded") @live
  success: bool,
  @s.describe(
    "The DOM content: line-oriented element descriptors in simplified mode, raw HTML in full mode. Absent when the subtree is too large."
  )
  @live
  html: option<string>,
  @s.describe("Number of element nodes in the returned subtree") @live
  nodeCount: option<int>,
  @s.describe("Size of the returned content in bytes") @live
  byteSize: option<int>,
  @s.describe(
    "Guidance for the next query: lists direct children when a request is rejected, or suggests narrower selectors."
  )
  @live
  hint: option<string>,
  @s.describe("Error message if the query failed") @live
  error: option<string>,
}

type Types.message<_> +=
  | GetDom(getDomInput): Types.message<getDomOutput>

let getDomError = (
  ~error: string,
  ~hint: option<string>=?,
  ~nodeCount: option<int>=?,
): getDomOutput => {
  success: false,
  html: None,
  nodeCount,
  byteSize: None,
  hint,
  error: Some(error),
}
