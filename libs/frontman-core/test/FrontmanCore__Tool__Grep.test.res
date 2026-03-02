// Tests for the Grep tool

open Vitest

module Grep = FrontmanCore__Tool__Grep
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module Os = FrontmanBindings.Os
module ChildProcess = FrontmanCore__ChildProcess

// Helper to create directory recursively
let mkdirRecursive = async (dir: string) => {
  let _ = await Fs.Promises.mkdir(dir, {recursive: true})
}

// Helper to remove directory recursively
let rmRecursive = async (dir: string) => {
  let _result = await ChildProcess.exec(`rm -rf ${dir}`)
}

// Helper to create a temporary test directory with files
let createTestFixture = async () => {
  let tempDir = Path.join([Os.tmpdir(), `grep-test-${Date.now()->Float.toString}`])
  await mkdirRecursive(tempDir)
  
  // Create test files
  await Fs.Promises.writeFile(
    Path.join([tempDir, "test1.js"]),
    `function hello() {
  console.log("Hello World");
}

const pricing = {
  basic: 10,
  premium: 50
};`,
  )
  
  await Fs.Promises.writeFile(
    Path.join([tempDir, "test2.ts"]),
    `interface PricingPlan {
  name: string;
  price: number;
}

const plans: PricingPlan[] = [
  { name: "Free", price: 0 },
  { name: "Pro", price: 29 }
];`,
  )
  
  await Fs.Promises.writeFile(
    Path.join([tempDir, "readme.md"]),
    `# Test Project

This is a test file.
PRICING information available.`,
  )
  
  // Create a subdirectory with files
  let subDir = Path.join([tempDir, "src"])
  await mkdirRecursive(subDir)
  
  await Fs.Promises.writeFile(
    Path.join([subDir, "utils.js"]),
    `export const calculatePrice = (qty) => qty * 10;
export const formatPricing = (price) => \`$\${price}\`;`,
  )
  
  tempDir
}

// Helper to clean up test directory
let cleanupTestFixture = async (dir: string) => {
  await rmRecursive(dir)
}

describe("Grep Tool - parseGrepOutput", _t => {
  test("should parse simple grep output", t => {
    let output = `test1.js:1:function hello() {
test1.js:5:const pricing = {
test2.ts:1:interface PricingPlan {`
    
    let result = Grep.parseGrepOutput(output, ~maxResults=100)
    
    t->expect(result.totalMatches)->Expect.toBe(3)
    t->expect(Array.length(result.files))->Expect.toBe(2)
    t->expect(result.truncated)->Expect.toBe(false)
  })
  
  test("should handle empty output", t => {
    let result = Grep.parseGrepOutput("", ~maxResults=100)
    
    t->expect(result.totalMatches)->Expect.toBe(0)
    t->expect(Array.length(result.files))->Expect.toBe(0)
    t->expect(result.truncated)->Expect.toBe(false)
  })
  
  test("should group matches by file", t => {
    let output = `test.js:1:line one
test.js:2:line two
other.js:5:line five`
    
    let result = Grep.parseGrepOutput(output, ~maxResults=100)
    
    t->expect(Array.length(result.files))->Expect.toBe(2)
    
    let testJsFile = result.files->Array.find(f => f.path === "test.js")
    switch testJsFile {
    | Some(file) => t->expect(Array.length(file.matches))->Expect.toBe(2)
    | None => failwith("test.js file not found")
    }
  })
  
  test("should respect maxResults", t => {
    // maxResults caps number of files, not individual matches
    let output = `a.js:1:one
b.js:2:two
c.js:3:three
d.js:4:four`
    
    let result = Grep.parseGrepOutput(output, ~maxResults=2)
    
    // All 4 matches counted, but only 2 files returned
    t->expect(result.totalMatches)->Expect.toBe(4)
    t->expect(Array.length(result.files))->Expect.toBe(2)
    t->expect(result.truncated)->Expect.toBe(true)
  })
  
  test("should handle paths with colons correctly", t => {
    let output = `/Users/test/file.js:10:const x = 5;
/Users/test/other.js:20:const y = 10;`
    
    let result = Grep.parseGrepOutput(output, ~maxResults=100)
    
    t->expect(Array.length(result.files))->Expect.toBe(2)
    t->expect(result.files[0]->Option.map(f => f.path))->Expect.toEqual(Some("/Users/test/file.js"))
  })
})

describe("Grep Tool - buildRipgrepArgs", _t => {
  test("should build basic args", t => {
    let args = Grep.buildRipgrepArgs(
      ~pattern="test",
      ~searchPath="/tmp",
      ~type_=None,
      ~glob=None,
      ~caseInsensitive=false,
      ~literal=false,
      ~maxResults=100,
    )
    
    t->expect(args->Array.includes("-n"))->Expect.toBe(true)
    t->expect(args->Array.includes("-H"))->Expect.toBe(true)
    t->expect(args->Array.includes("test"))->Expect.toBe(true)
    t->expect(args->Array.includes("/tmp"))->Expect.toBe(true)
  })
  
  test("should add case insensitive flag", t => {
    let args = Grep.buildRipgrepArgs(
      ~pattern="test",
      ~searchPath="/tmp",
      ~type_=None,
      ~glob=None,
      ~caseInsensitive=true,
      ~literal=false,
      ~maxResults=100,
    )
    
    t->expect(args->Array.includes("-i"))->Expect.toBe(true)
  })
  
  test("should add literal flag", t => {
    let args = Grep.buildRipgrepArgs(
      ~pattern="test",
      ~searchPath="/tmp",
      ~type_=None,
      ~glob=None,
      ~caseInsensitive=false,
      ~literal=true,
      ~maxResults=100,
    )
    
    t->expect(args->Array.includes("-F"))->Expect.toBe(true)
  })
  
  test("should add type filter", t => {
    let args = Grep.buildRipgrepArgs(
      ~pattern="test",
      ~searchPath="/tmp",
      ~type_=Some("js"),
      ~glob=None,
      ~caseInsensitive=false,
      ~literal=false,
      ~maxResults=100,
    )
    
    t->expect(args->Array.includes("-t"))->Expect.toBe(true)
    t->expect(args->Array.includes("js"))->Expect.toBe(true)
  })
  
  test("should add glob filter", t => {
    let args = Grep.buildRipgrepArgs(
      ~pattern="test",
      ~searchPath="/tmp",
      ~type_=None,
      ~glob=Some("*.tsx"),
      ~caseInsensitive=false,
      ~literal=false,
      ~maxResults=100,
    )
    
    t->expect(args->Array.includes("--glob"))->Expect.toBe(true)
    t->expect(args->Array.includes("*.tsx"))->Expect.toBe(true)
  })
})

describe("Grep Tool - buildGitGrepArgs", _t => {
  test("should build basic args", t => {
    let args = Grep.buildGitGrepArgs(
      ~pattern="test",
      ~caseInsensitive=false,
      ~literal=false,
      ~maxResults=100,
      ~glob=None,
      ~type_=None,
    )
    
    t->expect(args->Array.includes("grep"))->Expect.toBe(true)
    t->expect(args->Array.includes("-n"))->Expect.toBe(true)
    t->expect(args->Array.includes("-H"))->Expect.toBe(true)
    t->expect(args->Array.includes("test"))->Expect.toBe(true)
    // No pathspec separator when no glob/type
    t->expect(args->Array.includes("--"))->Expect.toBe(false)
  })
  
  test("should add case insensitive flag", t => {
    let args = Grep.buildGitGrepArgs(
      ~pattern="test",
      ~caseInsensitive=true,
      ~literal=false,
      ~maxResults=100,
      ~glob=None,
      ~type_=None,
    )
    
    t->expect(args->Array.includes("-i"))->Expect.toBe(true)
  })

  test("should add glob pathspec after -- separator", t => {
    let args = Grep.buildGitGrepArgs(
      ~pattern="demo",
      ~caseInsensitive=false,
      ~literal=false,
      ~maxResults=100,
      ~glob=Some("*.astro"),
      ~type_=None,
    )

    t->expect(args->Array.includes("--"))->Expect.toBe(true)
    t->expect(args->Array.includes("*.astro"))->Expect.toBe(true)

    // Verify order: pattern before --, glob after --
    let patternIdx = args->Array.indexOf("demo")
    let separatorIdx = args->Array.indexOf("--")
    let globIdx = args->Array.indexOf("*.astro")
    t->expect(patternIdx < separatorIdx)->Expect.toBe(true)
    t->expect(separatorIdx < globIdx)->Expect.toBe(true)
  })

  test("should convert type_ to glob pathspec", t => {
    let args = Grep.buildGitGrepArgs(
      ~pattern="test",
      ~caseInsensitive=false,
      ~literal=false,
      ~maxResults=100,
      ~glob=None,
      ~type_=Some("js"),
    )

    t->expect(args->Array.includes("--"))->Expect.toBe(true)
    t->expect(args->Array.includes("*.js"))->Expect.toBe(true)
  })

  test("should prefer glob over type_ when both are provided", t => {
    let args = Grep.buildGitGrepArgs(
      ~pattern="test",
      ~caseInsensitive=false,
      ~literal=false,
      ~maxResults=100,
      ~glob=Some("*.tsx"),
      ~type_=Some("js"),
    )

    // glob should be present, type-derived glob should not
    t->expect(args->Array.includes("*.tsx"))->Expect.toBe(true)
    t->expect(args->Array.includes("*.js"))->Expect.toBe(false)
  })

  test("should preserve multi-word patterns as a single arg element", t => {
    let args = Grep.buildGitGrepArgs(
      ~pattern="Frontman demo video",
      ~caseInsensitive=false,
      ~literal=false,
      ~maxResults=100,
      ~glob=None,
      ~type_=None,
    )

    // The pattern should be a single element in the array, not split on spaces.
    // This is what caused the original bug when args were joined into a shell string.
    t->expect(args->Array.includes("Frontman demo video"))->Expect.toBe(true)
  })
})

describe("Grep Tool - buildPlainGrepArgs", _t => {
  test("should build basic args", t => {
    let args = Grep.buildPlainGrepArgs(
      ~pattern="test",
      ~searchPath="/tmp",
      ~caseInsensitive=false,
      ~literal=false,
      ~maxResults=100,
      ~glob=None,
      ~type_=None,
    )

    t->expect(args->Array.includes("-rn"))->Expect.toBe(true)
    t->expect(args->Array.includes("test"))->Expect.toBe(true)
    t->expect(args->Array.includes("/tmp"))->Expect.toBe(true)
    t->expect(args->Array.includes("--exclude-dir=node_modules"))->Expect.toBe(true)
  })
})

describe("Grep Tool - execute (integration)", _t => {
  testAsync("should search files with ripgrep", async t => {
    let tempDir = await createTestFixture()
    
    try {
      let ctx: Tool.serverExecutionContext = {
        projectRoot: tempDir,
        sourceRoot: tempDir,
      }
      
      let input: Grep.input = {
        pattern: "pricing",
        caseInsensitive: true,
      }
      
      let result = await Grep.execute(ctx, input)
      
      switch result {
      | Ok(output) => {
          Console.log2("Search results:", output)
          t->expect(output.totalMatches > 0)->Expect.toBe(true)
          t->expect(Array.length(output.files) > 0)->Expect.toBe(true)
          
          // Verify we found pricing in the test files
          let hasPricing = output.files->Array.some(file => 
            file.matches->Array.some(m => 
              m.lineText->String.toLowerCase->String.includes("pricing")
            )
          )
          t->expect(hasPricing)->Expect.toBe(true)
        }
      | Error(msg) => failwith(`Grep failed: ${msg}`)
      }
    } catch {
    | exn => {
        let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        failwith(`Test failed with exception: ${msg}`)
      }
    }
    
    await cleanupTestFixture(tempDir)
  })
  
  testAsync("should handle case sensitive search", async t => {
    let tempDir = await createTestFixture()
    
    try {
      let ctx: Tool.serverExecutionContext = {
        projectRoot: tempDir,
        sourceRoot: tempDir,
      }
      
      // Search for "PRICING" (uppercase) with case sensitive
      let input: Grep.input = {
        pattern: "PRICING",
        caseInsensitive: false,
      }
      
      let result = await Grep.execute(ctx, input)
      
      switch result {
      | Ok(output) => {
          Console.log2("Case sensitive results:", output)
          // Should only find "PRICING" in readme.md
          t->expect(output.totalMatches > 0)->Expect.toBe(true)
          
          // All matches should be uppercase PRICING
          let allUppercase = output.files->Array.every(file =>
            file.matches->Array.every(m =>
              m.lineText->String.includes("PRICING")
            )
          )
          t->expect(allUppercase)->Expect.toBe(true)
        }
      | Error(msg) => failwith(`Grep failed: ${msg}`)
      }
    } catch {
    | exn => {
        let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        failwith(`Test failed: ${msg}`)
      }
    }
    
    await cleanupTestFixture(tempDir)
  })
  
  testAsync("should search in subdirectories", async t => {
    let tempDir = await createTestFixture()
    
    try {
      let ctx: Tool.serverExecutionContext = {
        projectRoot: tempDir,
        sourceRoot: tempDir,
      }
      
      let input: Grep.input = {
        pattern: "formatPricing",
      }
      
      let result = await Grep.execute(ctx, input)
      
      switch result {
      | Ok(output) => {
          Console.log2("Subdirectory search results:", output)
          t->expect(output.totalMatches > 0)->Expect.toBe(true)
          
          // Should find the file in src/utils.js
          let foundInSrc = output.files->Array.some(file =>
            file.path->String.includes("src")
          )
          t->expect(foundInSrc)->Expect.toBe(true)
        }
      | Error(msg) => failwith(`Grep failed: ${msg}`)
      }
    } catch {
    | exn => {
        let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        failwith(`Test failed: ${msg}`)
      }
    }
    
    await cleanupTestFixture(tempDir)
  })
  
  testAsync("should handle file path as search path (not just directories)", async t => {
    let tempDir = await createTestFixture()

    try {
      let ctx: Tool.serverExecutionContext = {
        projectRoot: tempDir,
        sourceRoot: tempDir,
      }

      // Pass a specific file path (not a directory) — this is what the LLM
      // does when it wants to search within a single file.
      let input: Grep.input = {
        pattern: "pricing",
        path: "test1.js",
        caseInsensitive: true,
      }

      let result = await Grep.execute(ctx, input)

      switch result {
      | Ok(output) => {
          // Should find "pricing" in test1.js without ENOTDIR
          t->expect(output.totalMatches > 0)->Expect.toBe(true)
          t->expect(Array.length(output.files) > 0)->Expect.toBe(true)
        }
      | Error(msg) => failwith(`Grep should not fail on file paths: ${msg}`)
      }
    } catch {
    | exn => {
        let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        failwith(`Test failed with exception: ${msg}`)
      }
    }

    await cleanupTestFixture(tempDir)
  })

  testAsync("should handle no matches gracefully", async t => {
    let tempDir = await createTestFixture()
    
    try {
      let ctx: Tool.serverExecutionContext = {
        projectRoot: tempDir,
        sourceRoot: tempDir,
      }
      
      let input: Grep.input = {
        pattern: "nonexistentpattern12345xyz",
      }
      
      let result = await Grep.execute(ctx, input)
      
      switch result {
      | Ok(output) => {
          t->expect(output.totalMatches)->Expect.toBe(0)
          t->expect(Array.length(output.files))->Expect.toBe(0)
        }
      | Error(msg) => failwith(`Grep should not error on no matches: ${msg}`)
      }
    } catch {
    | exn => {
        let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        failwith(`Test failed: ${msg}`)
      }
    }
    
    await cleanupTestFixture(tempDir)
  })
})

