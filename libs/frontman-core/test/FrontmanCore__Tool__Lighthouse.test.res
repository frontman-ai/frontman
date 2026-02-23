// Tests for the Lighthouse tool

open Vitest

module Lighthouse = FrontmanCore__Tool__Lighthouse
module LighthouseBindings = FrontmanBindings.Lighthouse
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool

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
    ~scoreDisplayMode: string="numeric",
    ~displayValue: option<string>=None,
  ): LighthouseBindings.auditResult => {
    id,
    title,
    description: `Description for ${title}`,
    score: Nullable.make(score),
    scoreDisplayMode,
    displayValue,
    numericValue: None,
  }
}

// --- Tests ---

describe("Lighthouse Tool - input validation", _t => {
  testAsync("should reject invalid preset", async t => {
    let result = await Lighthouse.execute(mockCtx, {url: "http://example.com", preset: "invalid"})

    switch result {
    | Ok(_) => failwith("Expected error for invalid preset")
    | Error(msg) => {
        t->expect(msg->String.includes("Invalid preset"))->Expect.toBe(true)
        t->expect(msg->String.includes("desktop"))->Expect.toBe(true)
        t->expect(msg->String.includes("mobile"))->Expect.toBe(true)
      }
    }
  })
})

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
      ("audit-2", Mock.makeAudit(~id="audit-2", ~title="Audit 2", ~score=0.3, ~scoreDisplayMode="binary", ~displayValue=Some("Bad"))),
      ("audit-3", Mock.makeAudit(~id="audit-3", ~title="Audit 3", ~score=0.6)),
      ("audit-4", Mock.makeAudit(~id="audit-4", ~title="Audit 4", ~score=1.0, ~scoreDisplayMode="binary")),
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
        scoreDisplayMode: "informative",
        displayValue: None,
        numericValue: None,
      }: LighthouseBindings.auditResult),
    ])

    let topIssues = Lighthouse.getTopIssues(~category, ~audits, ~maxIssues=3)

    t->expect(topIssues->Array.length)->Expect.toBe(0)
  })
})
