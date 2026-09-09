@schema
type input = {
  @s.describe(
    "CSS selector or XPath expression targeting a DOM subtree. Target the smallest subtree you need. CSS examples: '#main-content', '.hero-section', '[role=\"navigation\"]'. XPath examples: '//form', '//div[@id=\"app\"]'"
  )
  selector: string,
  @s.describe(
    "Output mode: 'simplified' (default) returns line-oriented element descriptors, 'full' returns raw outerHTML (capped at 15KB, use only for small components)."
  )
  mode: option<[#full | #simplified]>,
  @s.describe(
    "Maximum target subtree depth in simplified mode. Defaults to 1. Descriptors report child counts at the depth boundary. Call get_dom again with a returned selector to inspect another part of the tree."
  )
  maxDepth: option<int>,
  @s.describe(
    "Maximum number of element nodes to include. Defaults to 200. Simplified mode stops at this limit and returns a narrowing hint; full mode rejects larger subtrees."
  )
  maxNodes: option<int>,
  @s.describe(
    "Whether simplified mode traverses open shadow DOM roots. Defaults to false. Returned indexed paths use ' >>> ' at each shadow boundary and can be passed back as selector."
  )
  pierceShadowDom: option<bool>,
}

@schema
type output = {
  @s.describe("Current preview URL") @live
  url: string,
  @s.describe(
    "The DOM content: line-oriented element descriptors in simplified mode, raw HTML in full mode."
  )
  @live
  html: string,
  @s.describe("Number of element nodes in the returned subtree") @live
  nodeCount: int,
  @s.describe("Size of the returned content in bytes") @live
  byteSize: int,
  @s.describe("Guidance for narrowing the next query when simplified output is truncated.") @live
  hint: option<string>,
}
