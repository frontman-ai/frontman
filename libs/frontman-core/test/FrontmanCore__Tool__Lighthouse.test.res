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

describe("Lighthouse Tool - metadata", _t => {
  test("should have correct name", t => {
    t->expect(Lighthouse.name)->Expect.toBe("lighthouse")
  })

  test("should be visible to agent", t => {
    t->expect(Lighthouse.visibleToAgent)->Expect.toBe(true)
  })

  test("should have description with usage info", t => {
    let description = Lighthouse.description
    t->expect(description->String.includes("WHEN TO USE"))->Expect.toBe(true)
    t->expect(description->String.includes("PARAMETERS"))->Expect.toBe(true)
    t->expect(description->String.includes("LIMITATIONS"))->Expect.toBe(true)
  })
})

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
  // Test the internal LHR processing logic with mock data
  test("should extract category scores correctly", t => {
    // Create mock LHR data
    let perfCategory: LighthouseBindings.category = {
      id: "performance",
      title: "Performance",
      description: Some("Performance metrics"),
      score: Nullable.make(0.85),
      auditRefs: [],
    }
    let a11yCategory: LighthouseBindings.category = {
      id: "accessibility",
      title: "Accessibility",
      description: Some("Accessibility audits"),
      score: Nullable.make(0.92),
      auditRefs: [],
    }

    let mockLhr: LighthouseBindings.lhr = {
      lighthouseVersion: "12.0.0",
      fetchTime: "2024-01-01T00:00:00.000Z",
      requestedUrl: Some("http://example.com"),
      finalDisplayedUrl: "http://example.com",
      audits: Dict.make(),
      categories: Dict.fromArray([("performance", perfCategory), ("accessibility", a11yCategory)]),
      runWarnings: [],
    }

    let result = Lighthouse.processLhr(mockLhr)

    t->expect(result.url)->Expect.toBe("http://example.com")
    t->expect(result.categories->Array.length)->Expect.toBe(2)

    // Check performance category
    let perfResult = result.categories->Array.find(c => c.id === "performance")
    switch perfResult {
    | Some(cat) => t->expect(cat.score)->Expect.toBe(85)
    | None => failwith("Performance category not found")
    }

    // Check accessibility category
    let a11yResult = result.categories->Array.find(c => c.id === "accessibility")
    switch a11yResult {
    | Some(cat) => t->expect(cat.score)->Expect.toBe(92)
    | None => failwith("Accessibility category not found")
    }
  })

  test("should calculate overall score as average", t => {
    let perfCategory: LighthouseBindings.category = {
      id: "performance",
      title: "Performance",
      description: None,
      score: Nullable.make(0.80), // 80
      auditRefs: [],
    }
    let a11yCategory: LighthouseBindings.category = {
      id: "accessibility",
      title: "Accessibility",
      description: None,
      score: Nullable.make(1.0), // 100
      auditRefs: [],
    }

    let mockLhr: LighthouseBindings.lhr = {
      lighthouseVersion: "12.0.0",
      fetchTime: "2024-01-01T00:00:00.000Z",
      requestedUrl: Some("http://example.com"),
      finalDisplayedUrl: "http://example.com",
      audits: Dict.make(),
      categories: Dict.fromArray([("performance", perfCategory), ("accessibility", a11yCategory)]),
      runWarnings: [],
    }

    let result = Lighthouse.processLhr(mockLhr)

    // (80 + 100) / 2 = 90
    t->expect(result.overallScore)->Expect.toBe(90)
  })
})

describe("Lighthouse Tool - getTopIssues", _t => {
  test("should return top failing audits sorted by score", t => {
    // Create mock audit refs
    let auditRef1: LighthouseBindings.auditRef = {id: "audit-1", weight: 1.0}
    let auditRef2: LighthouseBindings.auditRef = {id: "audit-2", weight: 1.0}
    let auditRef3: LighthouseBindings.auditRef = {id: "audit-3", weight: 1.0}
    let auditRef4: LighthouseBindings.auditRef = {id: "audit-4", weight: 1.0}

    // Create mock category with audit refs
    let category: LighthouseBindings.category = {
      id: "performance",
      title: "Performance",
      description: None,
      score: Nullable.make(0.75),
      auditRefs: [auditRef1, auditRef2, auditRef3, auditRef4],
    }

    // Create mock audits
    let audit1: LighthouseBindings.auditResult = {
      id: "audit-1",
      title: "Audit 1",
      description: "Desc 1",
      score: Nullable.make(0.9), // Good score - should be last
      scoreDisplayMode: "numeric",
      displayValue: None,
      numericValue: None,
    }
    let audit2: LighthouseBindings.auditResult = {
      id: "audit-2",
      title: "Audit 2",
      description: "Desc 2",
      score: Nullable.make(0.3), // Bad score - should be first
      scoreDisplayMode: "binary",
      displayValue: Some("Bad"),
      numericValue: None,
    }
    let audit3: LighthouseBindings.auditResult = {
      id: "audit-3",
      title: "Audit 3",
      description: "Desc 3",
      score: Nullable.make(0.6), // Medium score
      scoreDisplayMode: "numeric",
      displayValue: None,
      numericValue: None,
    }
    let audit4: LighthouseBindings.auditResult = {
      id: "audit-4",
      title: "Audit 4",
      description: "Desc 4",
      score: Nullable.make(1.0), // Perfect score - should be excluded
      scoreDisplayMode: "binary",
      displayValue: None,
      numericValue: None,
    }

    let audits = Dict.fromArray([
      ("audit-1", audit1),
      ("audit-2", audit2),
      ("audit-3", audit3),
      ("audit-4", audit4),
    ])

    let topIssues = Lighthouse.getTopIssues(~category, ~audits, ~maxIssues=3)

    // Should have 3 issues (audit-4 excluded because score === 1.0)
    t->expect(topIssues->Array.length)->Expect.toBe(3)

    // First should be the worst (audit-2 with score 0.3)
    switch topIssues->Array.get(0) {
    | Some(issue) => {
        t->expect(issue.id)->Expect.toBe("audit-2")
        t->expect(issue.score)->Expect.toBe(0.3)
      }
    | None => failwith("Expected first issue")
    }

    // Second should be audit-3 with score 0.6
    switch topIssues->Array.get(1) {
    | Some(issue) => {
        t->expect(issue.id)->Expect.toBe("audit-3")
        t->expect(issue.score)->Expect.toBe(0.6)
      }
    | None => failwith("Expected second issue")
    }
  })

  test("should filter out informative audits", t => {
    let auditRef: LighthouseBindings.auditRef = {id: "info-audit", weight: 1.0}

    let category: LighthouseBindings.category = {
      id: "seo",
      title: "SEO",
      description: None,
      score: Nullable.make(0.9),
      auditRefs: [auditRef],
    }

    let infoAudit: LighthouseBindings.auditResult = {
      id: "info-audit",
      title: "Info Audit",
      description: "Just informational",
      score: Nullable.null, // Informative audits have null score
      scoreDisplayMode: "informative",
      displayValue: None,
      numericValue: None,
    }

    let audits = Dict.fromArray([("info-audit", infoAudit)])

    let topIssues = Lighthouse.getTopIssues(~category, ~audits, ~maxIssues=3)

    // Should have no issues since informative audits are excluded
    t->expect(topIssues->Array.length)->Expect.toBe(0)
  })
})
