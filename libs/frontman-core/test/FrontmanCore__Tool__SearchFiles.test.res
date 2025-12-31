// Tests for the SearchFiles tool

open Vitest

module SearchFiles = FrontmanCore__Tool__SearchFiles
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module Os = FrontmanBindings.Os
module ChildProcess = FrontmanBindings.ChildProcess

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
  let tempDir = Path.join([Os.tmpdir(), `searchfiles-test-${Date.now()->Float.toString}`])
  await mkdirRecursive(tempDir)
  
  // Create test files with various extensions
  await Fs.Promises.writeFile(
    Path.join([tempDir, "config.json"]),
    `{"name": "test"}`,
  )
  
  await Fs.Promises.writeFile(
    Path.join([tempDir, "app.config.ts"]),
    `export const config = {};`,
  )
  
  await Fs.Promises.writeFile(
    Path.join([tempDir, "readme.md"]),
    `# Test Project`,
  )
  
  await Fs.Promises.writeFile(
    Path.join([tempDir, "index.test.ts"]),
    `test("example", () => {});`,
  )
  
  await Fs.Promises.writeFile(
    Path.join([tempDir, "utils.test.js"]),
    `test("utils", () => {});`,
  )
  
  // Create subdirectories
  let srcDir = Path.join([tempDir, "src"])
  await mkdirRecursive(srcDir)
  
  await Fs.Promises.writeFile(
    Path.join([srcDir, "index.ts"]),
    `export const main = () => {};`,
  )
  
  await Fs.Promises.writeFile(
    Path.join([srcDir, "helper.test.ts"]),
    `test("helper", () => {});`,
  )
  
  let componentsDir = Path.join([tempDir, "src", "components"])
  await mkdirRecursive(componentsDir)
  
  await Fs.Promises.writeFile(
    Path.join([componentsDir, "Button.tsx"]),
    `export const Button = () => {};`,
  )
  
  await Fs.Promises.writeFile(
    Path.join([componentsDir, "Input.tsx"]),
    `export const Input = () => {};`,
  )
  
  // Create a config directory
  let configDir = Path.join([tempDir, "config"])
  await mkdirRecursive(configDir)
  
  await Fs.Promises.writeFile(
    Path.join([configDir, "database.config.js"]),
    `module.exports = {};`,
  )
  
  tempDir
}

// Helper to clean up test directory
let cleanupTestFixture = async (dir: string) => {
  await rmRecursive(dir)
}

describe("SearchFiles Tool - parseRipgrepOutput", _t => {
  test("should parse simple file list", t => {
    let output = `test.js
config.json
readme.md`
    
    let result = SearchFiles.parseRipgrepOutput(output, ~pattern="test", ~type_=None, ~maxResults=100)
    
    t->expect(result.totalResults)->Expect.toBe(1)
    t->expect(Array.length(result.files))->Expect.toBe(1)
    t->expect(result.truncated)->Expect.toBe(false)
    t->expect(result.files[0])->Expect.toEqual(Some("test.js"))
  })
  
  test("should handle empty output", t => {
    let result = SearchFiles.parseRipgrepOutput("", ~pattern="test", ~type_=None, ~maxResults=100)
    
    t->expect(result.totalResults)->Expect.toBe(0)
    t->expect(Array.length(result.files))->Expect.toBe(0)
    t->expect(result.truncated)->Expect.toBe(false)
  })
  
  test("should filter by pattern", t => {
    let output = `test.js
config.json
test.config.ts
readme.md`
    
    let result = SearchFiles.parseRipgrepOutput(output, ~pattern="config", ~type_=None, ~maxResults=100)
    
    t->expect(result.totalResults)->Expect.toBe(2)
    t->expect(Array.length(result.files))->Expect.toBe(2)
  })
  
  test("should respect maxResults", t => {
    let output = `test1.js
test2.js
test3.js
test4.js`
    
    let result = SearchFiles.parseRipgrepOutput(output, ~pattern="test", ~type_=None, ~maxResults=2)
    
    t->expect(result.totalResults)->Expect.toBe(4)
    t->expect(Array.length(result.files))->Expect.toBe(2)
    t->expect(result.truncated)->Expect.toBe(true)
  })
  
  test("should handle glob patterns with wildcards", t => {
    let output = `test.ts
test.js
config.test.ts
app.test.js
readme.md`
    
    let result = SearchFiles.parseRipgrepOutput(output, ~pattern="*.test.ts", ~type_=None, ~maxResults=100)
    
    t->expect(result.totalResults)->Expect.toBe(1)
    t->expect(result.files[0]->Option.map(f => f->String.endsWith("config.test.ts")))->Expect.toEqual(Some(true))
  })
  
  test("should handle multiple wildcards", t => {
    let output = `app.config.ts
app.test.ts
config.json
test.config.js`
    
    let result = SearchFiles.parseRipgrepOutput(output, ~pattern="*.config.*", ~type_=None, ~maxResults=100)
    
    // Should match app.config.ts and test.config.js
    t->expect(result.totalResults >= 2)->Expect.toBe(true)
  })
  
  test("should be case insensitive", t => {
    let output = `Config.json
CONFIG.ts
config.js`
    
    let result = SearchFiles.parseRipgrepOutput(output, ~pattern="config", ~type_=None, ~maxResults=100)
    
    t->expect(result.totalResults)->Expect.toBe(3)
  })
  
  test("should filter by type - files only", t => {
    let output = `test.js
config/
readme.md
src/`
    
    let result = SearchFiles.parseRipgrepOutput(output, ~pattern=".", ~type_=Some("file"), ~maxResults=100)
    
    // Should only match files (without trailing slash)
    t->expect(result.totalResults)->Expect.toBe(2)
  })
  
  test("should filter by type - directories only", t => {
    let output = `test.js
config/
readme.md
src/`
    
    let result = SearchFiles.parseRipgrepOutput(output, ~pattern="", ~type_=Some("directory"), ~maxResults=100)
    
    // Should match all directories (with trailing slash) - empty pattern matches all
    t->expect(result.totalResults)->Expect.toBe(2)
  })
})

describe("SearchFiles Tool - parseGitLsFilesOutput", _t => {
  test("should parse git ls-files output", t => {
    let output = `test.js
config.json
readme.md`
    
    let result = SearchFiles.parseGitLsFilesOutput(output, ~maxResults=100)
    
    t->expect(result.totalResults)->Expect.toBe(3)
    t->expect(Array.length(result.files))->Expect.toBe(3)
    t->expect(result.truncated)->Expect.toBe(false)
  })
  
  test("should respect maxResults", t => {
    let output = `file1.js
file2.js
file3.js
file4.js`
    
    let result = SearchFiles.parseGitLsFilesOutput(output, ~maxResults=2)
    
    t->expect(result.totalResults)->Expect.toBe(4)
    t->expect(Array.length(result.files))->Expect.toBe(2)
    t->expect(result.truncated)->Expect.toBe(true)
  })
})

describe("SearchFiles Tool - buildRipgrepArgs", _t => {
  test("should build basic args", t => {
    let args = SearchFiles.buildRipgrepArgs(~searchPath="/tmp")
    
    t->expect(args->Array.includes("--files"))->Expect.toBe(true)
    t->expect(args->Array.includes("--hidden"))->Expect.toBe(true)
    t->expect(args->Array.includes("--no-ignore"))->Expect.toBe(true)
    t->expect(args->Array.includes("/tmp"))->Expect.toBe(true)
  })
})

describe("SearchFiles Tool - execute (integration)", _t => {
  testAsync("should find files by name pattern", async t => {
    let tempDir = await createTestFixture()
    
    try {
      let ctx: Tool.serverExecutionContext = {
        projectRoot: tempDir,
        sourceRoot: tempDir,
      }
      
      let input: SearchFiles.input = {
        pattern: "config",
      }
      
      let result = await SearchFiles.execute(ctx, input)
      
      switch result {
      | Ok(output) => {
          Console.log2("Search results:", output)
          t->expect(output.totalResults > 0)->Expect.toBe(true)
          t->expect(Array.length(output.files) > 0)->Expect.toBe(true)
          
          // Verify we found config files
          let hasConfig = output.files->Array.some(file => 
            file->String.toLowerCase->String.includes("config")
          )
          t->expect(hasConfig)->Expect.toBe(true)
        }
      | Error(msg) => failwith(`SearchFiles failed: ${msg}`)
      }
    } catch {
    | exn => {
        let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        failwith(`Test failed with exception: ${msg}`)
      }
    }
    
    await cleanupTestFixture(tempDir)
  })
  
  testAsync("should find test files with glob pattern", async t => {
    let tempDir = await createTestFixture()
    
    try {
      let ctx: Tool.serverExecutionContext = {
        projectRoot: tempDir,
        sourceRoot: tempDir,
      }
      
      let input: SearchFiles.input = {
        pattern: "*.test.*",
      }
      
      let result = await SearchFiles.execute(ctx, input)
      
      switch result {
      | Ok(output) => {
          Console.log2("Test file results:", output)
          t->expect(output.totalResults > 0)->Expect.toBe(true)
          
          // All results should contain ".test."
          let allTestFiles = output.files->Array.every(file =>
            file->String.includes(".test.")
          )
          t->expect(allTestFiles)->Expect.toBe(true)
        }
      | Error(msg) => failwith(`SearchFiles failed: ${msg}`)
      }
    } catch {
    | exn => {
        let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        failwith(`Test failed: ${msg}`)
      }
    }
    
    await cleanupTestFixture(tempDir)
  })
  
  testAsync("should find files in subdirectories", async t => {
    let tempDir = await createTestFixture()
    
    try {
      let ctx: Tool.serverExecutionContext = {
        projectRoot: tempDir,
        sourceRoot: tempDir,
      }
      
      let input: SearchFiles.input = {
        pattern: "Button.tsx",
      }
      
      let result = await SearchFiles.execute(ctx, input)
      
      switch result {
      | Ok(output) => {
          Console.log2("Subdirectory search results:", output)
          t->expect(output.totalResults > 0)->Expect.toBe(true)
          
          // Should find Button.tsx in components directory
          let foundButton = output.files->Array.some(file =>
            file->String.includes("Button.tsx")
          )
          t->expect(foundButton)->Expect.toBe(true)
        }
      | Error(msg) => failwith(`SearchFiles failed: ${msg}`)
      }
    } catch {
    | exn => {
        let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        failwith(`Test failed: ${msg}`)
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
      
      let input: SearchFiles.input = {
        pattern: "nonexistentfile12345xyz.impossible",
      }
      
      let result = await SearchFiles.execute(ctx, input)
      
      switch result {
      | Ok(output) => {
          t->expect(output.totalResults)->Expect.toBe(0)
          t->expect(Array.length(output.files))->Expect.toBe(0)
        }
      | Error(msg) => failwith(`SearchFiles should not error on no matches: ${msg}`)
      }
    } catch {
    | exn => {
        let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        failwith(`Test failed: ${msg}`)
      }
    }
    
    await cleanupTestFixture(tempDir)
  })
  
  testAsync("should respect maxResults limit", async t => {
    let tempDir = await createTestFixture()
    
    try {
      let ctx: Tool.serverExecutionContext = {
        projectRoot: tempDir,
        sourceRoot: tempDir,
      }
      
      let input: SearchFiles.input = {
        pattern: ".", // Match anything
        maxResults: 3,
      }
      
      let result = await SearchFiles.execute(ctx, input)
      
      switch result {
      | Ok(output) => {
          Console.log2("Max results test:", output)
          t->expect(Array.length(output.files) <= 3)->Expect.toBe(true)
          
          if output.totalResults > 3 {
            t->expect(output.truncated)->Expect.toBe(true)
          }
        }
      | Error(msg) => failwith(`SearchFiles failed: ${msg}`)
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

