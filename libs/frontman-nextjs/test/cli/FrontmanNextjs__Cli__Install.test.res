open Vitest

module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path
module Process = Bindings.Process
module Os = Bindings.Os
module ChildProcess = FrontmanAiFrontmanCore.FrontmanCore__ChildProcess

module AutoEdit = FrontmanNextjs__Cli__AutoEdit
module Detect = FrontmanNextjs__Cli__Detect
module Files = FrontmanNextjs__Cli__Files
module Install = FrontmanNextjs__Cli__Install
module Templates = FrontmanNextjs__Cli__Templates

// Helper to get fixture path
let fixturesPath = Path.join([Process.cwd(), "test", "cli", "fixtures"])
let fixture = name => Path.join([fixturesPath, name])

// Derive Next.js version from fixture name (e.g. "nextjs15-clean" -> "15.0.0")
let nextVersionForFixture = (fixtureName: string): option<string> => {
  if fixtureName->String.startsWith("nextjs15") {
    Some("15.0.0")
  } else if fixtureName->String.startsWith("nextjs16") {
    Some("16.0.0")
  } else {
    None
  }
}

// Create mock node_modules/next/package.json in a directory
let setupMockNextVersion = async (dir: string, version: string) => {
  let nextDir = Path.join([dir, "node_modules", "next"])
  let _ = await Fs.Promises.mkdir(nextDir, {recursive: true})
  let content = `{"name":"next","version":"${version}"}`
  await Fs.Promises.writeFile(Path.join([nextDir, "package.json"]), content)
}

// Set up all fixture directories with mock node_modules
let fixtureNames = [
  "nextjs15-clean",
  "nextjs15-with-frontman",
  "nextjs15-with-middleware",
  "nextjs15-with-instrumentation",
  "nextjs15-with-src",
  "nextjs15-devdep",
  "nextjs16-clean",
  "nextjs16-with-frontman",
  "nextjs16-with-proxy",
]

let setupFixtures = async () => {
  let _ = await fixtureNames
  ->Array.map(async name => {
    let dir = fixture(name)
    switch nextVersionForFixture(name) {
    | Some(version) => await setupMockNextVersion(dir, version)
    | None => ()
    }

    // Create src/ directory for the with-src fixture
    if name->String.includes("with-src") {
      let srcDir = Path.join([dir, "src"])
      let _ = await Fs.Promises.mkdir(srcDir, {recursive: true})
    }
  })
  ->Promise.all
}

// Helper to create a temp copy of a fixture for testing
let createTempFixture = async (fixtureName: string): string => {
  let timestamp = Date.now()->Float.toString
  let tempDir = Path.join([Os.tmpdir(), `frontman-test-${timestamp}`])

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
  if nodeModulesExists {
    let _ = await ChildProcess.exec(`cp -r ${fixtureDir}/node_modules ${tempDir}/node_modules`)
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
  describe("Next.js Version Detection", _t => {
    testAsync(
      "detects Next.js 15 project",
      async t => {
        let dir = fixture("nextjs15-clean")
        let result = await Detect.detect(dir)

        switch result {
        | Ok(info) =>
          t->expect(info.nextVersion.major)->Expect.toBe(15)
          t->expect(info.nextVersion.raw)->Expect.toBe("15.0.0")
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "detects Next.js 16 project",
      async t => {
        let dir = fixture("nextjs16-clean")
        let result = await Detect.detect(dir)

        switch result {
        | Ok(info) =>
          t->expect(info.nextVersion.major)->Expect.toBe(16)
          t->expect(info.nextVersion.raw)->Expect.toBe("16.0.0")
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "detects Next.js in devDependencies",
      async t => {
        let dir = fixture("nextjs15-devdep")
        let result = await Detect.detect(dir)

        switch result {
        | Ok(info) =>
          t->expect(info.nextVersion.major)->Expect.toBe(15)
          t->expect(info.nextVersion.raw)->Expect.toBe("15.0.0")
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "fails for non-Next.js project",
      async t => {
        let dir = fixture("not-nextjs")
        let result = await Detect.detect(dir)

        switch result {
        | Error(msg) =>
          t->expect(msg->String.includes("not listed as a dependency"))->Expect.toBe(true)
        | Ok(_) => t->expect("should")->Expect.toBe("fail for non-nextjs project")
        }
      },
    )

    testAsync(
      "fails with specific error when next is declared but not installed",
      async t => {
        // Use an isolated temp dir so createRequire can't walk up and find next
        // in the monorepo's node_modules
        let timestamp = Date.now()->Float.toString
        let isolatedDir = Path.join([Os.tmpdir(), `frontman-not-installed-${timestamp}`])
        let _ = await Fs.Promises.mkdir(isolatedDir, {recursive: true})
        let content = `{"name":"test","version":"1.0.0","dependencies":{"next":"^15.0.0"}}`
        await Fs.Promises.writeFile(Path.join([isolatedDir, "package.json"]), content)

        let result = await Detect.detect(isolatedDir)

        switch result {
        | Error(msg) =>
          // Should mention it could not resolve next/package.json
          t->expect(msg->String.includes("Could not resolve"))->Expect.toBe(true)
        | Ok(_) => t->expect("should")->Expect.toBe("fail when next is not installed")
        }

        await cleanupTempFixture(isolatedDir)
      },
    )
  })

  describe("resolveFrom", _t => {
    testAsync(
      "resolves a module that exists",
      async t => {
        let dir = fixture("nextjs15-clean")
        // After setupFixtures, node_modules/next/package.json exists
        switch Detect.resolveFrom(dir, "next/package.json") {
        | Ok(path) => t->expect(path->String.includes("next"))->Expect.toBe(true)
        | Error(msg) => t->expect(msg)->Expect.toBe("should resolve successfully")
        }
      },
    )

    testAsync(
      "returns Error with message for missing module",
      async t => {
        let dir = fixture("not-nextjs")
        switch Detect.resolveFrom(dir, "nonexistent-package-xyz/package.json") {
        | Error(msg) =>
          // Should contain the module name and a meaningful error
          t->expect(msg->String.includes("nonexistent-package-xyz"))->Expect.toBe(true)
          t->expect(msg->String.length > 0)->Expect.toBe(true)
        | Ok(_) => t->expect("should")->Expect.toBe("fail for missing module")
        }
      },
    )
  })

  describe("hasNextDependency", _t => {
    testAsync(
      "returns true when next is in dependencies",
      async t => {
        let dir = fixture("nextjs15-clean")
        let result = await Detect.hasNextDependency(dir)
        t->expect(result)->Expect.toBe(true)
      },
    )

    testAsync(
      "returns true when next is in devDependencies",
      async t => {
        let dir = fixture("nextjs15-devdep")
        let result = await Detect.hasNextDependency(dir)
        t->expect(result)->Expect.toBe(true)
      },
    )

    testAsync(
      "returns false when next is not a dependency",
      async t => {
        let dir = fixture("not-nextjs")
        let result = await Detect.hasNextDependency(dir)
        t->expect(result)->Expect.toBe(false)
      },
    )

    testAsync(
      "returns false when package.json does not exist",
      async t => {
        let dir = Path.join([Os.tmpdir(), "nonexistent-dir-for-test"])
        let result = await Detect.hasNextDependency(dir)
        t->expect(result)->Expect.toBe(false)
      },
    )
  })

  describe("detectNextVersion", _t => {
    testAsync(
      "returns Ok with version when next is installed",
      async t => {
        let dir = fixture("nextjs15-clean")
        let result = await Detect.detectNextVersion(dir)

        switch result {
        | Ok(version) =>
          t->expect(version.major)->Expect.toBe(15)
          t->expect(version.minor)->Expect.toBe(0)
          t->expect(version.raw)->Expect.toBe("15.0.0")
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "returns Error when next is not a dependency",
      async t => {
        let dir = fixture("not-nextjs")
        let result = await Detect.detectNextVersion(dir)

        switch result {
        | Error(msg) =>
          t->expect(msg->String.includes("not listed as a dependency"))->Expect.toBe(true)
        | Ok(_) => t->expect("should")->Expect.toBe("return Error")
        }
      },
    )

    testAsync(
      "returns Error when next is declared but not installed",
      async t => {
        // Use an isolated temp dir so createRequire can't walk up and find next
        // in the monorepo's node_modules
        let timestamp = Date.now()->Float.toString
        let isolatedDir = Path.join([Os.tmpdir(), `frontman-detect-version-${timestamp}`])
        let _ = await Fs.Promises.mkdir(isolatedDir, {recursive: true})
        let content = `{"name":"test","version":"1.0.0","dependencies":{"next":"^15.0.0"}}`
        await Fs.Promises.writeFile(Path.join([isolatedDir, "package.json"]), content)

        let result = await Detect.detectNextVersion(isolatedDir)

        switch result {
        | Error(msg) => t->expect(msg->String.includes("Could not resolve"))->Expect.toBe(true)
        | Ok(_) => t->expect("should")->Expect.toBe("return Error for uninstalled dep")
        }

        await cleanupTempFixture(isolatedDir)
      },
    )
  })

  describe("Existing File Detection", _t => {
    testAsync(
      "detects existing middleware.ts without Frontman",
      async t => {
        let dir = fixture("nextjs15-with-middleware")
        let result = await Detect.detect(dir)

        switch result {
        | Ok(info) =>
          switch info.middleware {
          | NeedsManualEdit => t->expect(true)->Expect.toBe(true)
          | _ => t->expect("middleware")->Expect.toBe("NeedsManualEdit")
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "detects existing middleware.ts with Frontman and extracts host",
      async t => {
        let dir = fixture("nextjs15-with-frontman")
        let result = await Detect.detect(dir)

        switch result {
        | Ok(info) =>
          switch info.middleware {
          | HasFrontman({host}) => t->expect(host)->Expect.toBe("old-server.company.com")
          | _ => t->expect("middleware")->Expect.toBe("HasFrontman")
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "detects existing proxy.ts without Frontman",
      async t => {
        let dir = fixture("nextjs16-with-proxy")
        let result = await Detect.detect(dir)

        switch result {
        | Ok(info) =>
          switch info.proxy {
          | NeedsManualEdit => t->expect(true)->Expect.toBe(true)
          | _ => t->expect("proxy")->Expect.toBe("NeedsManualEdit")
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "detects existing proxy.ts with Frontman and extracts host",
      async t => {
        let dir = fixture("nextjs16-with-frontman")
        let result = await Detect.detect(dir)

        switch result {
        | Ok(info) =>
          switch info.proxy {
          | HasFrontman({host}) => t->expect(host)->Expect.toBe("old-server.company.com")
          | _ => t->expect("proxy")->Expect.toBe("HasFrontman")
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "detects existing instrumentation.ts without Frontman",
      async t => {
        let dir = fixture("nextjs15-with-instrumentation")
        let result = await Detect.detect(dir)

        switch result {
        | Ok(info) =>
          switch info.instrumentation {
          | NeedsManualEdit => t->expect(true)->Expect.toBe(true)
          | _ => t->expect("instrumentation")->Expect.toBe("NeedsManualEdit")
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )

    testAsync(
      "detects src/ directory",
      async t => {
        let dir = fixture("nextjs15-with-src")
        let result = await Detect.detect(dir)

        switch result {
        | Ok(info) => t->expect(info.hasSrcDir)->Expect.toBe(true)
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )
  })

  describe("Package Manager Detection", _t => {
    // We use npm by default for fixtures without lock files
    testAsync(
      "defaults to npm when no lock file present",
      async t => {
        let dir = fixture("nextjs15-clean")
        let result = await Detect.detect(dir)

        switch result {
        | Ok(info) =>
          switch info.packageManager {
          | Npm => t->expect(true)->Expect.toBe(true)
          | _ => t->expect("npm")->Expect.toBe("default package manager")
          }
        | Error(msg) => t->expect(msg)->Expect.toBe("should not fail")
        }
      },
    )
  })
})

describe("Next.js 15 Clean Install", _t => {
  testAsync("creates middleware.ts with correct content", async t => {
    let tempDir = await createTempFixture("nextjs15-clean")

    let _ = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    let content = await readTempFile(tempDir, "middleware.ts")

    switch content {
    | Some(c) =>
      t->expect(c->String.includes("@frontman-ai/nextjs"))->Expect.toBe(true)
      t->expect(c->String.includes("host: 'test.frontman.dev'"))->Expect.toBe(true)
      t->expect(c->String.includes("createMiddleware"))->Expect.toBe(true)
    | None => t->expect("middleware.ts")->Expect.toBe("should exist")
    }

    await cleanupTempFixture(tempDir)
  })

  testAsync("creates instrumentation.ts", async t => {
    let tempDir = await createTempFixture("nextjs15-clean")

    let _ = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    let exists = await tempFileExists(tempDir, "instrumentation.ts")
    t->expect(exists)->Expect.toBe(true)

    let content = await readTempFile(tempDir, "instrumentation.ts")
    switch content {
    | Some(c) =>
      t->expect(c->String.includes("@frontman-ai/nextjs/Instrumentation"))->Expect.toBe(true)
      t->expect(c->String.includes("NodeSDK"))->Expect.toBe(true)
    | None => t->expect("instrumentation.ts")->Expect.toBe("should have content")
    }

    await cleanupTempFixture(tempDir)
  })
})

describe("Next.js 16 Clean Install", _t => {
  testAsync("creates proxy.ts instead of middleware.ts", async t => {
    let tempDir = await createTempFixture("nextjs16-clean")

    let _ = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    // Should have proxy.ts
    let proxyContent = await readTempFile(tempDir, "proxy.ts")
    switch proxyContent {
    | Some(c) =>
      t->expect(c->String.includes("@frontman-ai/nextjs"))->Expect.toBe(true)
      t->expect(c->String.includes("host: 'test.frontman.dev'"))->Expect.toBe(true)
      t->expect(c->String.includes("function proxy"))->Expect.toBe(true)
      t->expect(c->String.includes("matcher"))->Expect.toBe(true)
      t->expect(c->String.includes("/frontman"))->Expect.toBe(true)
    | None => t->expect("proxy.ts")->Expect.toBe("should exist")
    }

    // Should NOT have middleware.ts (only proxy for Next.js 16+)
    let middlewareExists = await tempFileExists(tempDir, "middleware.ts")
    t->expect(middlewareExists)->Expect.toBe(false)

    await cleanupTempFixture(tempDir)
  })
})

describe("Host Update (Frontman Already Installed)", _t => {
  testAsync("updates host in middleware.ts", async t => {
    let tempDir = await createTempFixture("nextjs15-with-frontman")

    // Verify the old host exists
    let beforeContent = await readTempFile(tempDir, "middleware.ts")
    switch beforeContent {
    | Some(c) => t->expect(c->String.includes("old-server.company.com"))->Expect.toBe(true)
    | None => t->expect("middleware.ts")->Expect.toBe("should exist before")
    }

    let _ = await Install.run({
      server: "new-server.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    let afterContent = await readTempFile(tempDir, "middleware.ts")
    switch afterContent {
    | Some(c) =>
      t->expect(c->String.includes("new-server.frontman.dev"))->Expect.toBe(true)
      // Old host should be replaced
      t->expect(c->String.includes("old-server.company.com"))->Expect.toBe(false)
    | None => t->expect("middleware.ts")->Expect.toBe("should exist after")
    }

    await cleanupTempFixture(tempDir)
  })

  testAsync("updates host in proxy.ts", async t => {
    let tempDir = await createTempFixture("nextjs16-with-frontman")

    let _ = await Install.run({
      server: "new-server.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    let afterContent = await readTempFile(tempDir, "proxy.ts")
    switch afterContent {
    | Some(c) =>
      t->expect(c->String.includes("new-server.frontman.dev"))->Expect.toBe(true)
      t->expect(c->String.includes("old-server.company.com"))->Expect.toBe(false)
    | None => t->expect("proxy.ts")->Expect.toBe("should exist after")
    }

    await cleanupTempFixture(tempDir)
  })
})

describe("Existing Files Without Frontman", _t => {
  testAsync("errors for middleware.ts without Frontman", async t => {
    let tempDir = await createTempFixture("nextjs15-with-middleware")

    let result = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    switch result {
    | Install.PartialSuccess({manualStepsRequired}) =>
      // Should have manual steps for middleware
      let hasMiddlewareStep =
        manualStepsRequired->Array.some(s => s->String.includes("middleware.ts"))
      t->expect(hasMiddlewareStep)->Expect.toBe(true)
    | Install.Success => t->expect("should")->Expect.toBe("require manual steps")
    | Install.Failure(_) => t->expect("should")->Expect.toBe("partial success, not failure")
    }

    await cleanupTempFixture(tempDir)
  })

  testAsync("error includes correct manual setup steps", async t => {
    let tempDir = await createTempFixture("nextjs15-with-middleware")

    let result = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    switch result {
    | Install.PartialSuccess({manualStepsRequired}) =>
      let middlewareStep = manualStepsRequired->Array.find(s => s->String.includes("middleware.ts"))
      switch middlewareStep {
      | Some(step) =>
        t->expect(step->String.includes("createMiddleware"))->Expect.toBe(true)
        t->expect(step->String.includes("@frontman-ai/nextjs"))->Expect.toBe(true)
      | None => t->expect("middleware step")->Expect.toBe("should exist")
      }
    | _ => t->expect("should")->Expect.toBe("partial success")
    }

    await cleanupTempFixture(tempDir)
  })

  testAsync("errors for proxy.ts without Frontman", async t => {
    let tempDir = await createTempFixture("nextjs16-with-proxy")

    let result = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    switch result {
    | Install.PartialSuccess({manualStepsRequired}) =>
      let hasProxyStep = manualStepsRequired->Array.some(s => s->String.includes("proxy.ts"))
      t->expect(hasProxyStep)->Expect.toBe(true)
    | Install.Success => t->expect("should")->Expect.toBe("require manual steps")
    | Install.Failure(_) => t->expect("should")->Expect.toBe("partial success, not failure")
    }

    await cleanupTempFixture(tempDir)
  })

  testAsync("errors for instrumentation.ts without Frontman", async t => {
    let tempDir = await createTempFixture("nextjs15-with-instrumentation")

    let result = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    switch result {
    | Install.PartialSuccess({manualStepsRequired}) =>
      let hasInstrumentationStep =
        manualStepsRequired->Array.some(s => s->String.includes("instrumentation.ts"))
      t->expect(hasInstrumentationStep)->Expect.toBe(true)
    | Install.Success => t->expect("should")->Expect.toBe("require manual steps")
    | Install.Failure(_) => t->expect("should")->Expect.toBe("partial success, not failure")
    }

    await cleanupTempFixture(tempDir)
  })
})

describe("src/ Directory Support", _t => {
  testAsync("places instrumentation.ts in src/ when present", async t => {
    let tempDir = await createTempFixture("nextjs15-with-src")

    let _ = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: false,
      skipDeps: true,
    })

    // Should have instrumentation.ts in src/
    let srcInstrumentationExists = await tempFileExists(tempDir, "src/instrumentation.ts")
    t->expect(srcInstrumentationExists)->Expect.toBe(true)

    // Should NOT have instrumentation.ts in root
    let rootInstrumentationExists = await tempFileExists(tempDir, "instrumentation.ts")
    t->expect(rootInstrumentationExists)->Expect.toBe(false)

    await cleanupTempFixture(tempDir)
  })
})

describe("Host Replacement $ Injection Safety", _t => {
  test("escapeReplacement escapes dollar signs", t => {
    let result = Files.escapeReplacement("host-with-$1-injection")
    t->expect(result)->Expect.toBe("host-with-$$1-injection")
  })

  test("updateHostInContent handles host with $1 pattern", t => {
    let content = "const m = createMiddleware({ host: 'old.host.com' });"
    let updated = Files.updateHostInContent(content, "new-$1-host.com")
    t->expect(updated->String.includes("new-$1-host.com"))->Expect.toBe(true)
    t->expect(updated->String.includes("old.host.com"))->Expect.toBe(false)
  })

  test("updateHostInContent handles host with $& pattern", t => {
    let content = "const m = createMiddleware({ host: 'old.host.com' });"
    let updated = Files.updateHostInContent(content, "new-$&-host.com")
    t->expect(updated->String.includes("new-$&-host.com"))->Expect.toBe(true)
  })

  test("updateHostInContent handles host with $$ pattern", t => {
    let content = "const m = createMiddleware({ host: 'old.host.com' });"
    let updated = Files.updateHostInContent(content, "new-$$-host.com")
    t->expect(updated->String.includes("new-$$-host.com"))->Expect.toBe(true)
  })

  test("updateHostInContent works with normal host", t => {
    let content = "const m = createMiddleware({ host: 'old.host.com' });"
    let updated = Files.updateHostInContent(content, "new.host.com")
    t->expect(updated->String.includes("new.host.com"))->Expect.toBe(true)
    t->expect(updated->String.includes("old.host.com"))->Expect.toBe(false)
  })
})

describe("Batched Auto-Edit Collection", _t => {
  test("getPendingAutoEdit returns Some for NeedsManualEdit", t => {
    let result = Files.getPendingAutoEdit(
      ~existingFile=Detect.NeedsManualEdit,
      ~filePath="/tmp/middleware.ts",
      ~fileName="middleware.ts",
      ~fileType=AutoEdit.Middleware,
      ~manualDetails="manual details",
    )
    switch result {
    | Some(p) =>
      t->expect(p.fileName)->Expect.toBe("middleware.ts")
      t->expect(p.filePath)->Expect.toBe("/tmp/middleware.ts")
    | None => t->expect("should")->Expect.toBe("return Some")
    }
  })

  test("getPendingAutoEdit returns None for NotFound", t => {
    let result = Files.getPendingAutoEdit(
      ~existingFile=Detect.NotFound,
      ~filePath="/tmp/middleware.ts",
      ~fileName="middleware.ts",
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
      ~filePath="/tmp/middleware.ts",
      ~fileName="middleware.ts",
      ~fileType=AutoEdit.Middleware,
      ~manualDetails="manual details",
    )
    switch result {
    | None => t->expect(true)->Expect.toBe(true)
    | Some(_) => t->expect("should")->Expect.toBe("return None for HasFrontman")
    }
  })

  test("collectPendingAutoEdits collects middleware needing edit", t => {
    let info: Detect.projectInfo = {
      nextVersion: {major: 15, minor: 0, raw: "15.0.0"},
      middleware: Detect.NeedsManualEdit,
      proxy: Detect.NotFound,
      instrumentation: Detect.NotFound,
      hasSrcDir: false,
      packageManager: Detect.Npm,
    }
    let pending = Install.collectPendingAutoEdits(
      ~projectDir="/tmp",
      ~host="test.host",
      ~info,
      ~isNext16Plus=false,
    )
    t->expect(pending->Array.length)->Expect.toBe(1)
    t->expect((pending->Array.getUnsafe(0)).fileName)->Expect.toBe("middleware.ts")
  })

  test("collectPendingAutoEdits collects both middleware and instrumentation", t => {
    let info: Detect.projectInfo = {
      nextVersion: {major: 15, minor: 0, raw: "15.0.0"},
      middleware: Detect.NeedsManualEdit,
      proxy: Detect.NotFound,
      instrumentation: Detect.NeedsManualEdit,
      hasSrcDir: false,
      packageManager: Detect.Npm,
    }
    let pending = Install.collectPendingAutoEdits(
      ~projectDir="/tmp",
      ~host="test.host",
      ~info,
      ~isNext16Plus=false,
    )
    t->expect(pending->Array.length)->Expect.toBe(2)
    let fileNames = pending->Array.map(p => p.fileName)
    t->expect(fileNames->Array.includes("middleware.ts"))->Expect.toBe(true)
    t->expect(fileNames->Array.includes("instrumentation.ts"))->Expect.toBe(true)
  })

  test("collectPendingAutoEdits uses proxy for Next.js 16+", t => {
    let info: Detect.projectInfo = {
      nextVersion: {major: 16, minor: 0, raw: "16.0.0"},
      middleware: Detect.NeedsManualEdit,
      proxy: Detect.NeedsManualEdit,
      instrumentation: Detect.NotFound,
      hasSrcDir: false,
      packageManager: Detect.Npm,
    }
    let pending = Install.collectPendingAutoEdits(
      ~projectDir="/tmp",
      ~host="test.host",
      ~info,
      ~isNext16Plus=true,
    )
    t->expect(pending->Array.length)->Expect.toBe(1)
    t->expect((pending->Array.getUnsafe(0)).fileName)->Expect.toBe("proxy.ts")
  })

  test("collectPendingAutoEdits uses src/ path for instrumentation when hasSrcDir", t => {
    let info: Detect.projectInfo = {
      nextVersion: {major: 15, minor: 0, raw: "15.0.0"},
      middleware: Detect.NotFound,
      proxy: Detect.NotFound,
      instrumentation: Detect.NeedsManualEdit,
      hasSrcDir: true,
      packageManager: Detect.Npm,
    }
    let pending = Install.collectPendingAutoEdits(
      ~projectDir="/tmp",
      ~host="test.host",
      ~info,
      ~isNext16Plus=false,
    )
    t->expect(pending->Array.length)->Expect.toBe(1)
    t->expect((pending->Array.getUnsafe(0)).fileName)->Expect.toBe("src/instrumentation.ts")
  })

  test("collectPendingAutoEdits returns empty when no files need editing", t => {
    let info: Detect.projectInfo = {
      nextVersion: {major: 15, minor: 0, raw: "15.0.0"},
      middleware: Detect.NotFound,
      proxy: Detect.NotFound,
      instrumentation: Detect.NotFound,
      hasSrcDir: false,
      packageManager: Detect.Npm,
    }
    let pending = Install.collectPendingAutoEdits(
      ~projectDir="/tmp",
      ~host="test.host",
      ~info,
      ~isNext16Plus=false,
    )
    t->expect(pending->Array.length)->Expect.toBe(0)
  })
})

describe("Dry Run Mode", _t => {
  testAsync("does not create files in dry run", async t => {
    let tempDir = await createTempFixture("nextjs15-clean")

    let _ = await Install.run({
      server: "test.frontman.dev",
      prefix: Some(tempDir),
      dryRun: true,
      skipDeps: true,
    })

    // Should NOT have created middleware.ts
    let middlewareExists = await tempFileExists(tempDir, "middleware.ts")
    t->expect(middlewareExists)->Expect.toBe(false)

    // Should NOT have created instrumentation.ts
    let instrumentationExists = await tempFileExists(tempDir, "instrumentation.ts")
    t->expect(instrumentationExists)->Expect.toBe(false)

    await cleanupTempFixture(tempDir)
  })
})
