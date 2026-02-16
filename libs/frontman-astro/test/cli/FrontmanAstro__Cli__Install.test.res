open Vitest

module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path
module Process = Bindings.Process
module Os = Bindings.Os
module ChildProcess = Bindings.ChildProcess

module AutoEdit = FrontmanAstro__Cli__AutoEdit
module Detect = FrontmanAstro__Cli__Detect
module Files = FrontmanAstro__Cli__Files
module Install = FrontmanAstro__Cli__Install
module Templates = FrontmanAstro__Cli__Templates

// Helper to get fixture path
let fixturesPath = Path.join([Process.cwd(), "test", "cli", "fixtures"])
let fixture = name => Path.join([fixturesPath, name])

// Create mock node_modules/astro/package.json in a directory
let setupMockAstroVersion = async (dir: string, version: string) => {
  let astroDir = Path.join([dir, "node_modules", "astro"])
  let _ = await Fs.Promises.mkdir(astroDir, {recursive: true})
  let content = `{"name":"astro","version":"${version}"}`
  await Fs.Promises.writeFile(Path.join([astroDir, "package.json"]), content)
}

// Set up all fixture directories with mock node_modules
let fixtureNames = [
  "astro5-clean",
  "astro5-with-frontman",
  "astro5-with-middleware",
  "astro5-with-config",
  "astro5-with-js-middleware",
]

let setupFixtures = async () => {
  let _ = await fixtureNames->Array.map(async name => {
    let dir = fixture(name)
    await setupMockAstroVersion(dir, "5.0.0")
  })->Promise.all
}

// Helper to create a temp copy of a fixture for testing
let createTempFixture = async (fixtureName: string): string => {
  let timestamp = Date.now()->Float.toString
  let tempDir = Path.join([Os.tmpdir(), `frontman-astro-test-${timestamp}`])

  // Create temp directory
  let _ = await Fs.Promises.mkdir(tempDir, {recursive: true})

  // Copy fixture to temp (including node_modules set up by setupFixtures)
  let fixtureDir = fixture(fixtureName)
  let _ = await ChildProcess.exec(`cp -r ${fixtureDir}/* ${tempDir}/`)

  // Also copy node_modules which cp with glob might miss
  let nodeModulesExists = try {
    await Fs.Promises.access(Path.join([fixtureDir, "node_modules"]))
    true
  } catch {
  | _ => false
  }
  switch nodeModulesExists {
  | true =>
    let _ = await ChildProcess.exec(`cp -r ${fixtureDir}/node_modules ${tempDir}/node_modules`)
  | false => ()
  }

  // Copy src/ if it exists
  let srcExists = try {
    await Fs.Promises.access(Path.join([fixtureDir, "src"]))
    true
  } catch {
  | _ => false
  }
  switch srcExists {
  | true =>
    let _ = await ChildProcess.exec(`cp -r ${fixtureDir}/src ${tempDir}/src`)
  | false => ()
  }

  tempDir
}

// Helper to clean up temp fixture
let cleanupTempFixture = async (tempDir: string) => {
  let _ = await ChildProcess.exec(`rm -rf ${tempDir}`)
}

// Helper to read file content from temp dir
let readTempFile = async (tempDir: string, fileName: string): option<string> => {
  let filePath = Path.join([tempDir, fileName])
  try {
    let content = await Fs.Promises.readFile(filePath)
    Some(content)
  } catch {
  | _ => None
  }
}

// Helper to check if file exists in temp dir
let tempFileExists = async (tempDir: string, fileName: string): bool => {
  let filePath = Path.join([tempDir, fileName])
  try {
    await Fs.Promises.access(filePath)
    true
  } catch {
  | _ => false
  }
}

// Set up mock node_modules in all fixtures before tests run
beforeAllAsync(async () => {
  await setupFixtures()
})

describe("Project Detection", _t => {
  describe("Astro Version Detection", _t => {
    testAsync("detects Astro 5 project", async t => {
      let dir = fixture("astro5-clean")
      let result = await Detect.detect(dir)

      switch result {
      | Ok(info) =>
        switch info.astroVersion {
        | Some(version) =>
          t->expect(version.major)->Expect.toBe(5)
          t->expect(version.raw)->Expect.toBe("5.0.0")
        | None => t->expect("version")->Expect.toBe("should exist")
        }
      | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
      }
    })

    testAsync("fails for non-Astro project", async t => {
      let dir = fixture("not-astro")
      let result = await Detect.detect(dir)

      switch result {
      | Error(msg) => t->expect(msg->String.includes("Could not find Astro"))->Expect.toBe(true)
      | Ok(_) => t->expect("should")->Expect.toBe("fail for non-astro project")
      }
    })
  })

  describe("Existing File Detection", _t => {
    testAsync("detects existing config with Frontman and extracts host", async t => {
      let dir = fixture("astro5-with-frontman")
      let result = await Detect.detect(dir)

      switch result {
      | Ok(info) =>
        switch info.middleware {
        | HasFrontman({host}) => t->expect(host)->Expect.toBe("old-server.company.com")
        | _ => t->expect("middleware")->Expect.toBe("HasFrontman")
        }
      | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
      }
    })

    testAsync("detects existing middleware without Frontman", async t => {
      let dir = fixture("astro5-with-middleware")
      let result = await Detect.detect(dir)

      switch result {
      | Ok(info) =>
        switch info.middleware {
        | NeedsManualEdit => t->expect(true)->Expect.toBe(true)
        | _ => t->expect("middleware")->Expect.toBe("NeedsManualEdit")
        }
      | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
      }
    })

    testAsync("detects existing config without Frontman", async t => {
      let dir = fixture("astro5-with-config")
      let result = await Detect.detect(dir)

      switch result {
      | Ok(info) =>
        switch info.config {
        | NeedsManualEdit => t->expect(true)->Expect.toBe(true)
        | _ => t->expect("config")->Expect.toBe("NeedsManualEdit")
        }
      | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
      }
    })

    testAsync("detects config file name", async t => {
      let dir = fixture("astro5-with-config")
      let result = await Detect.detect(dir)

      switch result {
      | Ok(info) => t->expect(info.configFileName)->Expect.toBe("astro.config.mjs")
      | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
      }
    })
  })

  describe("Package Manager Detection", _t => {
    testAsync("defaults to npm when no lock file present", async t => {
      let dir = fixture("astro5-clean")
      let result = await Detect.detect(dir)

      switch result {
      | Ok(info) =>
        switch info.packageManager {
        | Npm => t->expect(true)->Expect.toBe(true)
        | _ => t->expect("npm")->Expect.toBe("default package manager")
        }
      | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
      }
    })
  })
})

describe("Astro 5 Clean Install", _t => {
  testAsync("creates astro.config.mjs with correct content", async t => {
    let tempDir = await createTempFixture("astro5-clean")

    let _ = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    let content = await readTempFile(tempDir, "astro.config.mjs")

    switch content {
    | Some(c) =>
      t->expect(c->String.includes("frontmanIntegration"))->Expect.toBe(true)
      t->expect(c->String.includes("@frontman-ai/astro"))->Expect.toBe(true)
      t->expect(c->String.includes("defineConfig"))->Expect.toBe(true)
      t->expect(c->String.includes("@astrojs/node"))->Expect.toBe(true)
    | None => t->expect("astro.config.mjs")->Expect.toBe("should exist")
    }

    await cleanupTempFixture(tempDir)
  })

  testAsync("creates src/middleware.ts with correct content", async t => {
    let tempDir = await createTempFixture("astro5-clean")

    let _ = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    let content = await readTempFile(tempDir, "src/middleware.ts")

    switch content {
    | Some(c) =>
      t->expect(c->String.includes("@frontman-ai/astro"))->Expect.toBe(true)
      t->expect(c->String.includes("createMiddleware"))->Expect.toBe(true)
      t->expect(c->String.includes("makeConfig"))->Expect.toBe(true)
      t->expect(c->String.includes("host: 'test.frontman.dev'"))->Expect.toBe(true)
      t->expect(c->String.includes("onRequest"))->Expect.toBe(true)
    | None => t->expect("src/middleware.ts")->Expect.toBe("should exist")
    }

    await cleanupTempFixture(tempDir)
  })
})

describe("Host Update (Frontman Already Installed)", _t => {
  testAsync("updates host in src/middleware.ts", async t => {
    let tempDir = await createTempFixture("astro5-with-frontman")

    // Verify the old host exists
    let beforeContent = await readTempFile(tempDir, "src/middleware.ts")
    switch beforeContent {
    | Some(c) => t->expect(c->String.includes("old-server.company.com"))->Expect.toBe(true)
    | None => t->expect("src/middleware.ts")->Expect.toBe("should exist before")
    }

    let _ = await Install.run({
      server: "new-server.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    let afterContent = await readTempFile(tempDir, "src/middleware.ts")
    switch afterContent {
    | Some(c) =>
      t->expect(c->String.includes("new-server.frontman.dev"))->Expect.toBe(true)
      // Old host should be replaced
      t->expect(c->String.includes("old-server.company.com"))->Expect.toBe(false)
    | None => t->expect("src/middleware.ts")->Expect.toBe("should exist after")
    }

    await cleanupTempFixture(tempDir)
  })
})

describe("Existing Files Without Frontman", _t => {
  testAsync("requires manual edit for middleware without Frontman", async t => {
    let tempDir = await createTempFixture("astro5-with-middleware")

    let result = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    switch result {
    | Install.PartialSuccess({manualStepsRequired}) =>
      // Should have manual steps for middleware
      let hasMiddlewareStep = manualStepsRequired->Array.some(s => s->String.includes("middleware"))
      t->expect(hasMiddlewareStep)->Expect.toBe(true)
    | Install.Success => t->expect("should")->Expect.toBe("require manual steps")
    | Install.Failure(_) => t->expect("should")->Expect.toBe("partial success, not failure")
    }

    await cleanupTempFixture(tempDir)
  })

  testAsync("requires manual edit for config without Frontman", async t => {
    let tempDir = await createTempFixture("astro5-with-config")

    let result = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    switch result {
    | Install.PartialSuccess({manualStepsRequired}) =>
      // Should have manual steps for config
      let hasConfigStep = manualStepsRequired->Array.some(s => s->String.includes("astro.config"))
      t->expect(hasConfigStep)->Expect.toBe(true)
    | Install.Success => t->expect("should")->Expect.toBe("require manual steps")
    | Install.Failure(_) => t->expect("should")->Expect.toBe("partial success, not failure")
    }

    await cleanupTempFixture(tempDir)
  })

  testAsync("manual step includes correct setup instructions", async t => {
    let tempDir = await createTempFixture("astro5-with-middleware")

    let result = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    switch result {
    | Install.PartialSuccess({manualStepsRequired}) =>
      let middlewareStep = manualStepsRequired->Array.find(s => s->String.includes("middleware"))
      switch middlewareStep {
      | Some(step) =>
        t->expect(step->String.includes("createMiddleware"))->Expect.toBe(true)
        t->expect(step->String.includes("@frontman-ai/astro"))->Expect.toBe(true)
      | None => t->expect("middleware step")->Expect.toBe("should exist")
      }
    | _ => t->expect("should")->Expect.toBe("partial success")
    }

    await cleanupTempFixture(tempDir)
  })
})

describe("Batched Auto-Edit Collection", _t => {
  test("getPendingAutoEdit returns Some for NeedsManualEdit", t => {
    let result = Files.getPendingAutoEdit(
      ~existingFile=Detect.NeedsManualEdit,
      ~filePath="/tmp/src/middleware.ts",
      ~fileName="src/middleware.ts",
      ~fileType=AutoEdit.Middleware,
      ~manualDetails="manual details",
    )
    switch result {
    | Some(p) =>
      t->expect(p.fileName)->Expect.toBe("src/middleware.ts")
      t->expect(p.filePath)->Expect.toBe("/tmp/src/middleware.ts")
    | None => t->expect("should")->Expect.toBe("return Some")
    }
  })

  test("getPendingAutoEdit returns None for NotFound", t => {
    let result = Files.getPendingAutoEdit(
      ~existingFile=Detect.NotFound,
      ~filePath="/tmp/src/middleware.ts",
      ~fileName="src/middleware.ts",
      ~fileType=AutoEdit.Middleware,
      ~manualDetails="manual details",
    )
    switch result {
    | None => t->expect(true)->Expect.toBe(true)
    | Some(_) => t->expect("should")->Expect.toBe("return None for NotFound")
    }
  })

  test("getPendingAutoEdit returns None for HasFrontman", t => {
    let result = Files.getPendingAutoEdit(
      ~existingFile=Detect.HasFrontman({host: "test.host"}),
      ~filePath="/tmp/src/middleware.ts",
      ~fileName="src/middleware.ts",
      ~fileType=AutoEdit.Middleware,
      ~manualDetails="manual details",
    )
    switch result {
    | None => t->expect(true)->Expect.toBe(true)
    | Some(_) => t->expect("should")->Expect.toBe("return None for HasFrontman")
    }
  })

  test("collectPendingAutoEdits collects config needing edit", t => {
    let info: Detect.projectInfo = {
      astroVersion: Some({major: 5, minor: 0, raw: "5.0.0"}),
      config: Detect.NeedsManualEdit,
      middleware: Detect.NotFound,
      configFileName: "astro.config.mjs",
      middlewareFileName: "src/middleware.ts",
      packageManager: Detect.Npm,
    }
    let pending = Install.collectPendingAutoEdits(
      ~projectDir="/tmp",
      ~host="test.host",
      ~info,
    )
    t->expect(pending->Array.length)->Expect.toBe(1)
    t->expect((pending->Array.getUnsafe(0)).fileName)->Expect.toBe("astro.config.mjs")
  })

  test("collectPendingAutoEdits collects both config and middleware", t => {
    let info: Detect.projectInfo = {
      astroVersion: Some({major: 5, minor: 0, raw: "5.0.0"}),
      config: Detect.NeedsManualEdit,
      middleware: Detect.NeedsManualEdit,
      configFileName: "astro.config.mjs",
      middlewareFileName: "src/middleware.ts",
      packageManager: Detect.Npm,
    }
    let pending = Install.collectPendingAutoEdits(
      ~projectDir="/tmp",
      ~host="test.host",
      ~info,
    )
    t->expect(pending->Array.length)->Expect.toBe(2)
    let fileNames = pending->Array.map(p => p.fileName)
    t->expect(fileNames->Array.includes("astro.config.mjs"))->Expect.toBe(true)
    t->expect(fileNames->Array.includes("src/middleware.ts"))->Expect.toBe(true)
  })

  test("collectPendingAutoEdits returns empty when no files need editing", t => {
    let info: Detect.projectInfo = {
      astroVersion: Some({major: 5, minor: 0, raw: "5.0.0"}),
      config: Detect.NotFound,
      middleware: Detect.NotFound,
      configFileName: "astro.config.mjs",
      middlewareFileName: "src/middleware.ts",
      packageManager: Detect.Npm,
    }
    let pending = Install.collectPendingAutoEdits(
      ~projectDir="/tmp",
      ~host="test.host",
      ~info,
    )
    t->expect(pending->Array.length)->Expect.toBe(0)
  })
})

describe("Host Replacement $ Injection Safety", _t => {
  test("escapeReplacement escapes dollar signs", t => {
    let result = Files.escapeReplacement("host-with-$1-injection")
    t->expect(result)->Expect.toBe("host-with-$$1-injection")
  })

  test("updateHostInContent handles host with $1 pattern", t => {
    let content = "const config = makeConfig({ host: 'old.host.com' });"
    let updated = Files.updateHostInContent(content, "new-$1-host.com")
    t->expect(updated->String.includes("new-$1-host.com"))->Expect.toBe(true)
    t->expect(updated->String.includes("old.host.com"))->Expect.toBe(false)
  })

  test("updateHostInContent works with normal host", t => {
    let content = "const config = makeConfig({ host: 'old.host.com' });"
    let updated = Files.updateHostInContent(content, "new.host.com")
    t->expect(updated->String.includes("new.host.com"))->Expect.toBe(true)
    t->expect(updated->String.includes("old.host.com"))->Expect.toBe(false)
  })
})

describe("Dry Run Mode", _t => {
  testAsync("does not create files in dry run", async t => {
    let tempDir = await createTempFixture("astro5-clean")

    let _ = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: true,
      skipDeps: true,
    })

    // Should NOT have created astro.config.mjs
    let configExists = await tempFileExists(tempDir, "astro.config.mjs")
    t->expect(configExists)->Expect.toBe(false)

    // Should NOT have created src/middleware.ts
    let middlewareExists = await tempFileExists(tempDir, "src/middleware.ts")
    t->expect(middlewareExists)->Expect.toBe(false)

    await cleanupTempFixture(tempDir)
  })
})

describe("JavaScript Middleware Support", _t => {
  testAsync("detects src/middleware.js and sets middlewareFileName", async t => {
    let dir = fixture("astro5-with-js-middleware")
    let result = await Detect.detect(dir)

    switch result {
    | Ok(info) =>
      t->expect(info.middlewareFileName)->Expect.toBe("src/middleware.js")
      switch info.middleware {
      | HasFrontman({host}) => t->expect(host)->Expect.toBe("old-js-server.company.com")
      | _ => t->expect("middleware")->Expect.toBe("HasFrontman")
      }
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  testAsync("updates host in src/middleware.js (not .ts)", async t => {
    let tempDir = await createTempFixture("astro5-with-js-middleware")

    // Verify old host exists in .js file
    let beforeContent = await readTempFile(tempDir, "src/middleware.js")
    switch beforeContent {
    | Some(c) => t->expect(c->String.includes("old-js-server.company.com"))->Expect.toBe(true)
    | None => t->expect("src/middleware.js")->Expect.toBe("should exist before")
    }

    let _ = await Install.run({
      server: "new-js-server.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    // .js file should be updated
    let afterContent = await readTempFile(tempDir, "src/middleware.js")
    switch afterContent {
    | Some(c) =>
      t->expect(c->String.includes("new-js-server.frontman.dev"))->Expect.toBe(true)
      t->expect(c->String.includes("old-js-server.company.com"))->Expect.toBe(false)
    | None => t->expect("src/middleware.js")->Expect.toBe("should exist after")
    }

    // Should NOT have created src/middleware.ts
    let tsExists = await tempFileExists(tempDir, "src/middleware.ts")
    t->expect(tsExists)->Expect.toBe(false)

    await cleanupTempFixture(tempDir)
  })

  testAsync("defaults middlewareFileName to src/middleware.ts when no middleware exists", async t => {
    let dir = fixture("astro5-clean")
    let result = await Detect.detect(dir)

    switch result {
    | Ok(info) =>
      t->expect(info.middlewareFileName)->Expect.toBe("src/middleware.ts")
      switch info.middleware {
      | NotFound => t->expect(true)->Expect.toBe(true)
      | _ => t->expect("middleware")->Expect.toBe("NotFound")
      }
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }
  })

  test("collectPendingAutoEdits uses middlewareFileName for .js", t => {
    let info: Detect.projectInfo = {
      astroVersion: Some({major: 5, minor: 0, raw: "5.0.0"}),
      config: Detect.NotFound,
      middleware: Detect.NeedsManualEdit,
      configFileName: "astro.config.mjs",
      middlewareFileName: "src/middleware.js",
      packageManager: Detect.Npm,
    }
    let pending = Install.collectPendingAutoEdits(
      ~projectDir="/tmp",
      ~host="test.host",
      ~info,
    )
    t->expect(pending->Array.length)->Expect.toBe(1)
    t->expect((pending->Array.getUnsafe(0)).fileName)->Expect.toBe("src/middleware.js")
  })
})

describe("Skip on Empty Host (non-extractable host)", _t => {
  testAsync("skips config when HasFrontman with empty host (re-install)", async t => {
    let tempDir = await createTempFixture("astro5-with-frontman")

    // The astro5-with-frontman fixture has config that imports frontman-astro
    // but host is only in middleware, so config analyzes as HasFrontman({host: ""})
    let configResult = await Files.handleConfig(
      ~projectDir=tempDir,
      ~host="any-new-host.dev",
      ~configFileName="astro.config.mjs",
      ~existingFile=Detect.HasFrontman({host: ""}),
      ~dryRun=false,
    )

    switch configResult {
    | Ok(Files.Skipped(_)) => t->expect(true)->Expect.toBe(true)
    | Ok(Files.Updated(_)) => t->expect("should")->Expect.toBe("skip, not update")
    | Ok(_) => t->expect("should")->Expect.toBe("skip")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }

    await cleanupTempFixture(tempDir)
  })

  testAsync("skips middleware when HasFrontman with empty host (e.g. env var host)", async t => {
    let tempDir = await createTempFixture("astro5-with-frontman")

    // When analyzeFile can't extract a host (e.g. host: process.env.FRONTMAN_HOST),
    // it returns HasFrontman({host: ""}). Should skip, not rewrite the file.
    let middlewareResult = await Files.handleMiddleware(
      ~projectDir=tempDir,
      ~host="any-new-host.dev",
      ~middlewareFileName="src/middleware.ts",
      ~existingFile=Detect.HasFrontman({host: ""}),
      ~dryRun=false,
    )

    switch middlewareResult {
    | Ok(Files.Skipped(_)) => t->expect(true)->Expect.toBe(true)
    | Ok(Files.Updated(_)) => t->expect("should")->Expect.toBe("skip, not update")
    | Ok(_) => t->expect("should")->Expect.toBe("skip")
    | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
    }

    await cleanupTempFixture(tempDir)
  })

  test("skips config when existingHost matches requested host", t => {
    let result = Files.getPendingAutoEdit(
      ~existingFile=Detect.HasFrontman({host: "same.host"}),
      ~filePath="/tmp/astro.config.mjs",
      ~fileName="astro.config.mjs",
      ~fileType=AutoEdit.Config,
      ~manualDetails="manual details",
    )
    switch result {
    | None => t->expect(true)->Expect.toBe(true)
    | Some(_) => t->expect("should")->Expect.toBe("return None for HasFrontman")
    }
  })
})
