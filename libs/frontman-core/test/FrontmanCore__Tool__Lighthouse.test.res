// Tests for the Lighthouse tool

open Vitest

module Lighthouse = FrontmanCore__Tool__Lighthouse
module LighthouseBindings = FrontmanBindings.Lighthouse
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

// Create a mock execution context
let mockCtx: Tool.serverExecutionContext = {
  projectRoot: "/tmp",
  sourceRoot: "/tmp",
}

// --- Test helpers ---

module Mock = {
  let makeCategory = (
    ~id: string,
    ~title: string,
    ~score: float,
    ~auditRefs: array<LighthouseBindings.auditRef>=[],
  ): LighthouseBindings.category => {
    id,
    title,
    description: None,
    score: Nullable.make(score),
    auditRefs,
  }

  let makeLhr = (~categories: array<(string, LighthouseBindings.category)>, ~audits=Dict.make()): LighthouseBindings.lhr => {
    lighthouseVersion: "12.0.0",
    fetchTime: "2024-01-01T00:00:00.000Z",
    requestedUrl: Some("http://example.com"),
    finalDisplayedUrl: "http://example.com",
    audits,
    categories: Dict.fromArray(categories),
    runWarnings: [],
  }

  let makeAudit = (
    ~id: string,
    ~title: string,
    ~score: float,
    ~scoreDisplayMode: LighthouseBindings.scoreDisplayMode=Numeric,
    ~displayValue: option<string>=None,
    ~details: option<JSON.t>=None,
  ): LighthouseBindings.auditResult => {
    id,
    title,
    description: `Description for ${title}`,
    score: Nullable.make(score),
    scoreDisplayMode,
    displayValue,
    numericValue: None,
    details,
  }
}

// --- Tests ---

// Preset validation is now enforced at the type level (variant type),
// so invalid presets are caught at compile time rather than runtime.

describe("Lighthouse Tool - processLhr", _t => {
  test("should extract category scores correctly", t => {
    let mockLhr = Mock.makeLhr(~categories=[
      ("performance", Mock.makeCategory(~id="performance", ~title="Performance", ~score=0.85)),
      ("accessibility", Mock.makeCategory(~id="accessibility", ~title="Accessibility", ~score=0.92)),
    ])

    let result = Lighthouse.processLhr(mockLhr)

    t->expect(result.url)->Expect.toBe("http://example.com")
    t->expect(result.categories->Array.length)->Expect.toBe(2)

    switch result.categories->Array.find(c => c.id === "performance") {
    | Some(cat) => t->expect(cat.score)->Expect.toBe(85)
    | None => failwith("Performance category not found")
    }

    switch result.categories->Array.find(c => c.id === "accessibility") {
    | Some(cat) => t->expect(cat.score)->Expect.toBe(92)
    | None => failwith("Accessibility category not found")
    }
  })

  test("should calculate overall score as average", t => {
    let mockLhr = Mock.makeLhr(~categories=[
      ("performance", Mock.makeCategory(~id="performance", ~title="Performance", ~score=0.80)),
      ("accessibility", Mock.makeCategory(~id="accessibility", ~title="Accessibility", ~score=1.0)),
    ])

    let result = Lighthouse.processLhr(mockLhr)

    // (80 + 100) / 2 = 90
    t->expect(result.overallScore)->Expect.toBe(90)
  })
})

describe("Lighthouse Tool - getTopIssues", _t => {
  test("should return top failing audits sorted by score", t => {
    let refs = [
      ({id: "audit-1", weight: 1.0}: LighthouseBindings.auditRef),
      {id: "audit-2", weight: 1.0},
      {id: "audit-3", weight: 1.0},
      {id: "audit-4", weight: 1.0},
    ]

    let category = Mock.makeCategory(~id="performance", ~title="Performance", ~score=0.75, ~auditRefs=refs)

    let audits = Dict.fromArray([
      ("audit-1", Mock.makeAudit(~id="audit-1", ~title="Audit 1", ~score=0.9)),
      ("audit-2", Mock.makeAudit(~id="audit-2", ~title="Audit 2", ~score=0.3, ~scoreDisplayMode=Binary, ~displayValue=Some("Bad"))),
      ("audit-3", Mock.makeAudit(~id="audit-3", ~title="Audit 3", ~score=0.6)),
      ("audit-4", Mock.makeAudit(~id="audit-4", ~title="Audit 4", ~score=1.0, ~scoreDisplayMode=Binary)),
    ])

    let topIssues = Lighthouse.getTopIssues(~category, ~audits, ~maxIssues=3)

    // audit-4 excluded (score === 1.0), remaining 3 sorted by score asc
    t->expect(topIssues->Array.length)->Expect.toBe(3)

    switch topIssues->Array.get(0) {
    | Some(issue) => {
        t->expect(issue.id)->Expect.toBe("audit-2")
        t->expect(issue.score)->Expect.toBe(0.3)
      }
    | None => failwith("Expected first issue")
    }

    switch topIssues->Array.get(1) {
    | Some(issue) => {
        t->expect(issue.id)->Expect.toBe("audit-3")
        t->expect(issue.score)->Expect.toBe(0.6)
      }
    | None => failwith("Expected second issue")
    }
  })

  test("should filter out informative audits", t => {
    let category = Mock.makeCategory(
      ~id="seo",
      ~title="SEO",
      ~score=0.9,
      ~auditRefs=[{id: "info-audit", weight: 1.0}],
    )

    let audits = Dict.fromArray([
      ("info-audit", {
        id: "info-audit",
        title: "Info Audit",
        description: "Just informational",
        score: Nullable.null,
        scoreDisplayMode: Informative,
        displayValue: None,
        numericValue: None,
        details: None,
      }: LighthouseBindings.auditResult),
    ])

    let topIssues = Lighthouse.getTopIssues(~category, ~audits, ~maxIssues=3)

    t->expect(topIssues->Array.length)->Expect.toBe(0)
  })

  test("should include empty elements array when audit has no details", t => {
    let refs = [({id: "audit-1", weight: 1.0}: LighthouseBindings.auditRef)]
    let category = Mock.makeCategory(
      ~id="performance",
      ~title="Performance",
      ~score=0.75,
      ~auditRefs=refs,
    )

    let audits = Dict.fromArray([
      ("audit-1", Mock.makeAudit(~id="audit-1", ~title="Audit 1", ~score=0.5)),
    ])

    let topIssues = Lighthouse.getTopIssues(~category, ~audits, ~maxIssues=3)

    switch topIssues->Array.get(0) {
    | Some(issue) => t->expect(issue.elements->Array.length)->Expect.toBe(0)
    | None => failwith("Expected issue")
    }
  })

  test("should extract node details from accessibility-style audit", t => {
    let refs = [({id: "image-alt", weight: 1.0}: LighthouseBindings.auditRef)]
    let category = Mock.makeCategory(
      ~id="accessibility",
      ~title="Accessibility",
      ~score=0.75,
      ~auditRefs=refs,
    )

    let nodeDetails = JSON.Encode.object(
      Dict.fromArray([
        ("type", JSON.Encode.string("table")),
        (
          "items",
          JSON.Encode.array([
            JSON.Encode.object(
              Dict.fromArray([
                (
                  "node",
                  JSON.Encode.object(
                    Dict.fromArray([
                      ("type", JSON.Encode.string("node")),
                      ("selector", JSON.Encode.string("body > main > img.hero")),
                      (
                        "snippet",
                        JSON.Encode.string(`<img src="/hero.jpg" class="hero">`),
                      ),
                      ("nodeLabel", JSON.Encode.string("hero")),
                      (
                        "explanation",
                        JSON.Encode.string("Element does not have an alt attribute"),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )

    let audits = Dict.fromArray([
      (
        "image-alt",
        Mock.makeAudit(
          ~id="image-alt",
          ~title="Image alt",
          ~score=0.0,
          ~scoreDisplayMode=Binary,
          ~details=Some(nodeDetails),
        ),
      ),
    ])

    let topIssues = Lighthouse.getTopIssues(~category, ~audits, ~maxIssues=3)

    switch topIssues->Array.get(0) {
    | Some(issue) => {
        t->expect(issue.elements->Array.length)->Expect.toBe(1)
        switch issue.elements->Array.get(0) {
        | Some(el) => {
            t->expect(el.selector)->Expect.toEqual(Some("body > main > img.hero"))
            t->expect(el.snippet)->Expect.toEqual(Some(`<img src="/hero.jpg" class="hero">`))
            t->expect(el.nodeLabel)->Expect.toEqual(Some("hero"))
            t->expect(el.explanation)->Expect.toEqual(Some("Element does not have an alt attribute"))
            t->expect(el.url)->Expect.toEqual(None)
          }
        | None => failwith("Expected element detail")
        }
      }
    | None => failwith("Expected issue")
    }
  })

  test("should extract resource URL from opportunity-style audit", t => {
    let refs = [({id: "render-blocking", weight: 1.0}: LighthouseBindings.auditRef)]
    let category = Mock.makeCategory(
      ~id="performance",
      ~title="Performance",
      ~score=0.60,
      ~auditRefs=refs,
    )

    let opportunityDetails = JSON.Encode.object(
      Dict.fromArray([
        ("type", JSON.Encode.string("opportunity")),
        (
          "items",
          JSON.Encode.array([
            JSON.Encode.object(
              Dict.fromArray([
                ("url", JSON.Encode.string("https://example.com/style.css")),
              ]),
            ),
            JSON.Encode.object(
              Dict.fromArray([
                ("url", JSON.Encode.string("https://example.com/app.js")),
              ]),
            ),
          ]),
        ),
      ]),
    )

    let audits = Dict.fromArray([
      (
        "render-blocking",
        Mock.makeAudit(
          ~id="render-blocking",
          ~title="Render Blocking Resources",
          ~score=0.2,
          ~scoreDisplayMode=MetricSavings,
          ~details=Some(opportunityDetails),
        ),
      ),
    ])

    let topIssues = Lighthouse.getTopIssues(~category, ~audits, ~maxIssues=3)

    switch topIssues->Array.get(0) {
    | Some(issue) => {
        t->expect(issue.elements->Array.length)->Expect.toBe(2)
        switch issue.elements->Array.get(0) {
        | Some(el) => {
            t->expect(el.url)->Expect.toEqual(Some("https://example.com/style.css"))
            t->expect(el.selector)->Expect.toEqual(None)
          }
        | None => failwith("Expected first element")
        }
      }
    | None => failwith("Expected issue")
    }
  })

  test("should limit elements to maxElementsPerIssue (3)", t => {
    let refs = [({id: "many-items", weight: 1.0}: LighthouseBindings.auditRef)]
    let category = Mock.makeCategory(
      ~id="accessibility",
      ~title="Accessibility",
      ~score=0.50,
      ~auditRefs=refs,
    )

    let makeNodeItem = (sel: string) =>
      JSON.Encode.object(
        Dict.fromArray([
          (
            "node",
            JSON.Encode.object(
              Dict.fromArray([
                ("type", JSON.Encode.string("node")),
                ("selector", JSON.Encode.string(sel)),
                ("snippet", JSON.Encode.string(`<div class="${sel}">`)),
              ]),
            ),
          ),
        ]),
      )

    let details = JSON.Encode.object(
      Dict.fromArray([
        ("type", JSON.Encode.string("table")),
        (
          "items",
          JSON.Encode.array([
            makeNodeItem("sel-1"),
            makeNodeItem("sel-2"),
            makeNodeItem("sel-3"),
            makeNodeItem("sel-4"),
            makeNodeItem("sel-5"),
          ]),
        ),
      ]),
    )

    let audits = Dict.fromArray([
      (
        "many-items",
        Mock.makeAudit(
          ~id="many-items",
          ~title="Many Items",
          ~score=0.0,
          ~scoreDisplayMode=Binary,
          ~details=Some(details),
        ),
      ),
    ])

    let topIssues = Lighthouse.getTopIssues(~category, ~audits, ~maxIssues=3)

    switch topIssues->Array.get(0) {
    | Some(issue) =>
      // Should be capped at 3 despite 5 items
      t->expect(issue.elements->Array.length)->Expect.toBe(3)
    | None => failwith("Expected issue")
    }
  })
})
