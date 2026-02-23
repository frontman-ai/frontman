// Comprehensive tests for the EditFile Matcher module
// Tests all 9 strategies individually + the applyEdit orchestrator

open Vitest

module Matcher = FrontmanCore__Tool__EditFile__Matcher

// ============================================
// Levenshtein Distance
// ============================================

describe("levenshtein", _t => {
  test("identical strings have distance 0", t => {
    t->expect(Matcher.levenshtein("hello", "hello"))->Expect.toBe(0)
  })

  test("empty vs non-empty is length of non-empty", t => {
    t->expect(Matcher.levenshtein("", "hello"))->Expect.toBe(5)
    t->expect(Matcher.levenshtein("hello", ""))->Expect.toBe(5)
  })

  test("both empty is 0", t => {
    t->expect(Matcher.levenshtein("", ""))->Expect.toBe(0)
  })

  test("single character substitution", t => {
    t->expect(Matcher.levenshtein("cat", "bat"))->Expect.toBe(1)
  })

  test("insertion", t => {
    t->expect(Matcher.levenshtein("cat", "cats"))->Expect.toBe(1)
  })

  test("deletion", t => {
    t->expect(Matcher.levenshtein("cats", "cat"))->Expect.toBe(1)
  })

  test("multiple edits", t => {
    t->expect(Matcher.levenshtein("kitten", "sitting"))->Expect.toBe(3)
  })
})

// ============================================
// Strategy 1: Exact Match
// ============================================

describe("exactMatch", _t => {
  test("finds exact substring", t => {
    let result = Matcher.exactMatch("hello world", "world")
    t->expect(result)->Expect.toEqual(["world"])
  })

  test("returns empty for no match", t => {
    let result = Matcher.exactMatch("hello world", "xyz")
    t->expect(result)->Expect.toEqual([])
  })

  test("finds multi-line match", t => {
    let content = "line1\nline2\nline3"
    let find = "line2\nline3"
    let result = Matcher.exactMatch(content, find)
    t->expect(result)->Expect.toEqual(["line2\nline3"])
  })
})

// ============================================
// Strategy 2: Line-Trimmed Match
// ============================================

describe("lineTrimMatch", _t => {
  test("matches when indentation differs", t => {
    let content = "  function hello() {\n    return 42;\n  }"
    let find = "function hello() {\n  return 42;\n}"
    let result = Matcher.lineTrimMatch(content, find)
    t->expect(result->Array.length)->Expect.toBe(1)
    // Should return the original indented content
    t->expect(result[0]->Option.getOrThrow)->Expect.toBe(content)
  })

  test("matches with trailing empty line in search", t => {
    let content = "  foo();\n  bar();"
    let find = "foo();\nbar();\n"
    let result = Matcher.lineTrimMatch(content, find)
    t->expect(result->Array.length)->Expect.toBe(1)
  })

  test("no match when content differs", t => {
    let content = "  foo();\n  bar();"
    let find = "foo();\nbaz();"
    let result = Matcher.lineTrimMatch(content, find)
    t->expect(result)->Expect.toEqual([])
  })

  test("finds match in middle of file", t => {
    let content = "header\n  target_line;\n  next_line;\nfooter"
    let find = "target_line;\nnext_line;"
    let result = Matcher.lineTrimMatch(content, find)
    t->expect(result->Array.length)->Expect.toBe(1)
    t->expect(result[0]->Option.getOrThrow)->Expect.toBe("  target_line;\n  next_line;")
  })
})

// ============================================
// Strategy 3: Block Anchor Match
// ============================================

describe("anchoredBlockMatch", _t => {
  test("matches with first/last line anchors and similar middle", t => {
    let content = "function test() {\n  const x = 1;\n  const y = 2;\n  return x + y;\n}"
    let find = "function test() {\n  const x = 10;\n  const y = 20;\n  return x + y;\n}"
    let result = Matcher.anchoredBlockMatch(content, find)
    t->expect(result->Array.length)->Expect.toBe(1)
  })

  test("returns empty for less than 3 lines", t => {
    let content = "line1\nline2"
    let find = "line1\nline2"
    let result = Matcher.anchoredBlockMatch(content, find)
    t->expect(result)->Expect.toEqual([])
  })

  test("returns empty when anchors don't match", t => {
    let content = "function a() {\n  body;\n}\nfunction b() {\n  other;\n}"
    let find = "function c() {\n  body;\n}"
    let result = Matcher.anchoredBlockMatch(content, find)
    t->expect(result)->Expect.toEqual([])
  })

  test("picks best match among multiple candidates", t => {
    let content = "start:\n  alpha;\nend:\nmore stuff\nstart:\n  beta;\nend:"
    let find = "start:\n  beta;\nend:"
    let result = Matcher.anchoredBlockMatch(content, find)
    t->expect(result->Array.length)->Expect.toBe(1)
    // Should pick the block with "beta" since it matches better
    t->expect(result[0]->Option.getOrThrow->String.includes("beta"))->Expect.toBe(true)
  })
})

// ============================================
// Strategy 4: Whitespace Normalized Match
// ============================================

describe("normalizedWhitespaceMatch", _t => {
  test("matches with different whitespace", t => {
    let content = "const   x   =   42;"
    let find = "const x = 42;"
    let result = Matcher.normalizedWhitespaceMatch(content, find)
    t->expect(result->Array.length > 0)->Expect.toBe(true)
  })

  test("matches multi-line with collapsed whitespace", t => {
    let content = "  if  (true)  {\n    return   1;\n  }"
    let find = "if (true) {\n  return 1;\n}"
    let result = Matcher.normalizedWhitespaceMatch(content, find)
    t->expect(result->Array.length > 0)->Expect.toBe(true)
  })

  test("no match when words differ", t => {
    let content = "const x = 42;"
    let find = "const y = 42;"
    let result = Matcher.normalizedWhitespaceMatch(content, find)
    t->expect(result)->Expect.toEqual([])
  })
})

// ============================================
// Strategy 5: Flexible Indentation Match
// ============================================

describe("flexibleIndentMatch", _t => {
  test("matches when base indentation differs", t => {
    let content = "    function hello() {\n      return 42;\n    }"
    let find = "function hello() {\n  return 42;\n}"
    let result = Matcher.flexibleIndentMatch(content, find)
    t->expect(result->Array.length)->Expect.toBe(1)
    // Returns the original (indented) content
    t->expect(result[0]->Option.getOrThrow)->Expect.toBe(content)
  })

  test("no match when relative indentation structure differs", t => {
    let content = "    function hello() {\n    return 42;\n    }"
    let find = "function hello() {\n    return 42;\n}"
    let result = Matcher.flexibleIndentMatch(content, find)
    t->expect(result)->Expect.toEqual([])
  })

  test("handles empty lines in blocks", t => {
    let content = "      a();\n\n      b();"
    let find = "  a();\n\n  b();"
    let result = Matcher.flexibleIndentMatch(content, find)
    t->expect(result->Array.length)->Expect.toBe(1)
  })
})

// ============================================
// Strategy 6: Escape Normalized Match
// ============================================

describe("escapeNormalizedMatch", _t => {
  test("matches escaped newlines against literal", t => {
    let content = "hello\nworld"
    let find = "hello\\nworld"
    let result = Matcher.escapeNormalizedMatch(content, find)
    t->expect(result->Array.length > 0)->Expect.toBe(true)
  })

  test("matches escaped tabs against literal", t => {
    let content = "hello\tworld"
    let find = "hello\\tworld"
    let result = Matcher.escapeNormalizedMatch(content, find)
    t->expect(result->Array.length > 0)->Expect.toBe(true)
  })

  test("matches escaped quotes", t => {
    let content = `She said "hello"`
    let find = `She said \\"hello\\"`
    let result = Matcher.escapeNormalizedMatch(content, find)
    t->expect(result->Array.length > 0)->Expect.toBe(true)
  })

  test("no match when unescaped content differs", t => {
    let content = "hello world"
    let find = "goodbye\\nworld"
    let result = Matcher.escapeNormalizedMatch(content, find)
    t->expect(result)->Expect.toEqual([])
  })
})

// ============================================
// Strategy 7: Trimmed Boundary Match
// ============================================

describe("trimmedBoundaryMatch", _t => {
  test("matches when search has leading/trailing whitespace", t => {
    let content = "hello world"
    let find = "  hello world  "
    let result = Matcher.trimmedBoundaryMatch(content, find)
    t->expect(result->Array.length > 0)->Expect.toBe(true)
  })

  test("matches when search has leading/trailing blank lines", t => {
    let content = "line1\nline2\nline3\nfoo\nbar"
    let find = "\nfoo\nbar\n"
    let result = Matcher.trimmedBoundaryMatch(content, find)
    t->expect(result->Array.length > 0)->Expect.toBe(true)
  })

  test("returns empty when already trimmed (no-op)", t => {
    let content = "hello world"
    let find = "hello world"
    let result = Matcher.trimmedBoundaryMatch(content, find)
    t->expect(result)->Expect.toEqual([])
  })

  test("returns empty when trimmed content not found", t => {
    let content = "hello world"
    let find = "  goodbye world  "
    let result = Matcher.trimmedBoundaryMatch(content, find)
    t->expect(result)->Expect.toEqual([])
  })
})

// ============================================
// Strategy 8: Context Anchor Match
// ============================================

describe("contextAnchorMatch", _t => {
  test("matches with 50% middle line agreement", t => {
    let content = "function foo() {\n  const a = 1;\n  const b = 2;\n  const c = 3;\n  return a;\n}"
    let find = "function foo() {\n  const a = 1;\n  const b = 99;\n  const c = 3;\n  return a;\n}"
    let result = Matcher.contextAnchorMatch(content, find)
    // 3 middle lines, 2 match exactly (a=1, c=3), 1 differs (b) => 67% >= 50%
    t->expect(result->Array.length)->Expect.toBe(1)
  })

  test("rejects with less than 50% middle match", t => {
    let content = "start\n  line1\n  line2\n  line3\n  line4\nend"
    let find = "start\n  changed1\n  changed2\n  changed3\n  line4\nend"
    let result = Matcher.contextAnchorMatch(content, find)
    // 4 middle lines, only 1 matches (line4) => 25% < 50%
    t->expect(result)->Expect.toEqual([])
  })

  test("returns empty for less than 3 lines", t => {
    let content = "line1\nline2"
    let find = "line1\nline2"
    let result = Matcher.contextAnchorMatch(content, find)
    t->expect(result)->Expect.toEqual([])
  })
})

// ============================================
// Strategy 9: Multi-Occurrence Match
// ============================================

describe("multiOccurrenceMatch", _t => {
  test("finds all occurrences", t => {
    let content = "foo bar foo baz foo"
    let find = "foo"
    let result = Matcher.multiOccurrenceMatch(content, find)
    t->expect(result->Array.length)->Expect.toBe(3)
  })

  test("returns empty for no match", t => {
    let content = "hello world"
    let find = "xyz"
    let result = Matcher.multiOccurrenceMatch(content, find)
    t->expect(result)->Expect.toEqual([])
  })

  test("finds single occurrence", t => {
    let content = "hello world"
    let find = "world"
    let result = Matcher.multiOccurrenceMatch(content, find)
    t->expect(result->Array.length)->Expect.toBe(1)
  })
})

// ============================================
// Orchestrator: applyEdit
// ============================================

describe("applyEdit", _t => {
  test("exact match replacement", t => {
    let result = Matcher.applyEdit(
      ~content="hello world",
      ~oldText="world",
      ~newText="universe",
    )
    t->expect(result)->Expect.toEqual(Matcher.Applied("hello universe"))
  })

  test("returns NotFound when text doesn't exist", t => {
    let result = Matcher.applyEdit(
      ~content="hello world",
      ~oldText="xyz",
      ~newText="abc",
    )
    t->expect(result)->Expect.toEqual(Matcher.NotFound)
  })

  test("returns Ambiguous for duplicate matches without replaceAll", t => {
    let result = Matcher.applyEdit(
      ~content="foo bar foo",
      ~oldText="foo",
      ~newText="baz",
    )
    t->expect(result)->Expect.toEqual(Matcher.Ambiguous)
  })

  test("replaceAll replaces all occurrences", t => {
    let result = Matcher.applyEdit(
      ~content="foo bar foo baz foo",
      ~oldText="foo",
      ~newText="qux",
      ~replaceAll=true,
    )
    t->expect(result)->Expect.toEqual(Matcher.Applied("qux bar qux baz qux"))
  })

  test("falls back to line-trimmed when exact fails", t => {
    let content = "  function hello() {\n    return 42;\n  }"
    let result = Matcher.applyEdit(
      ~content,
      ~oldText="function hello() {\n  return 42;\n}",
      ~newText="function hello() {\n  return 99;\n}",
    )
    switch result {
    | Applied(newContent) =>
      t->expect(newContent->String.includes("99"))->Expect.toBe(true)
      // Should preserve original indentation
      t->expect(newContent->String.includes("  function"))->Expect.toBe(false)
    | _ => failwith("Expected Applied result")
    }
  })

  test("handles indentation-flexible matching", t => {
    let content = "    function hello() {\n      return 42;\n    }"
    let result = Matcher.applyEdit(
      ~content,
      ~oldText="function hello() {\n  return 42;\n}",
      ~newText="function goodbye() {\n  return 99;\n}",
    )
    switch result {
    | Applied(newContent) =>
      t->expect(newContent->String.includes("goodbye"))->Expect.toBe(true)
    | _ => failwith("Expected Applied result")
    }
  })

  test("handles whitespace-normalized matching", t => {
    let content = "const   x   =   42;"
    let result = Matcher.applyEdit(
      ~content,
      ~oldText="const x = 42;",
      ~newText="const x = 99;",
    )
    switch result {
    | Applied(newContent) =>
      t->expect(newContent->String.includes("99"))->Expect.toBe(true)
    | _ => failwith("Expected Applied result")
    }
  })

  test("handles trimmed boundary matching", t => {
    let content = "hello world"
    let result = Matcher.applyEdit(
      ~content,
      ~oldText="\n  hello world  \n",
      ~newText="goodbye world",
    )
    switch result {
    | Applied(newContent) =>
      t->expect(newContent)->Expect.toBe("goodbye world")
    | _ => failwith("Expected Applied result")
    }
  })

  // Real-world LLM scenarios
  test("LLM adds extra indentation to React component", t => {
    let content = `export default function App() {
  return (
    <div>
      <h1>Hello</h1>
    </div>
  );
}`
    let result = Matcher.applyEdit(
      ~content,
      ~oldText=`return (
  <div>
    <h1>Hello</h1>
  </div>
);`,
      ~newText=`return (
  <div>
    <h1>Goodbye</h1>
  </div>
);`,
    )
    switch result {
    | Applied(newContent) =>
      t->expect(newContent->String.includes("Goodbye"))->Expect.toBe(true)
      t->expect(newContent->String.includes("Hello"))->Expect.toBe(false)
    | _ => failwith("Expected Applied result")
    }
  })

  test("LLM provides code block with wrong base indentation", t => {
    let content = `class MyClass {
    constructor() {
        this.value = 42;
        this.name = "test";
    }
}`
    let result = Matcher.applyEdit(
      ~content,
      ~oldText=`constructor() {
    this.value = 42;
    this.name = "test";
}`,
      ~newText=`constructor() {
    this.value = 99;
    this.name = "updated";
}`,
    )
    switch result {
    | Applied(newContent) =>
      t->expect(newContent->String.includes("99"))->Expect.toBe(true)
      t->expect(newContent->String.includes("updated"))->Expect.toBe(true)
    | _ => failwith("Expected Applied result")
    }
  })

  test("LLM escapes template literal dollar signs", t => {
    let content = "const msg = `Hello ${name}`;"
    let result = Matcher.applyEdit(
      ~content,
      ~oldText="const msg = `Hello \\${name}`;",
      ~newText="const msg = `Hi ${name}`;",
    )
    switch result {
    | Applied(newContent) =>
      t->expect(newContent->String.includes("Hi"))->Expect.toBe(true)
    | _ => failwith("Expected Applied result")
    }
  })

  test("replaceAll preserves dollar signs in newText literally", t => {
    let content = "const x = $$props; const y = $$props;"
    let result = Matcher.applyEdit(
      ~content,
      ~oldText="$$props",
      ~newText="$$restProps",
      ~replaceAll=true,
    )
    switch result {
    | Applied(newContent) =>
      // $$ must remain as $$ — not be collapsed to $ by JS replacement patterns
      t->expect(newContent)->Expect.toBe("const x = $$restProps; const y = $$restProps;")
    | _ => failwith("Expected Applied result")
    }
  })
})
