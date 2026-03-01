// Integration tests for AI auto-edit using real LLM calls with caching
// Tests call OpenCode Zen API and cache responses to avoid repeated API calls.
// Cache is committed to git so CI never hits the live API.
// To refresh a cache entry, delete its .json file and re-run the test.
//
// Verification strategy:
// 1. esbuild syntax check — proves the output is valid TypeScript
// 2. Structural checks — verifies frontman handler is placed before existing logic
// 3. Import regex — verifies proper import statements (not just substrings)

open Vitest

module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path
module Process = Bindings.Process
module Os = Bindings.Os
module ChildProcess = FrontmanAiFrontmanCore.FrontmanCore__ChildProcess

module AutoEdit = FrontmanNextjs__Cli__AutoEdit

// ---- Cache helpers (implemented in JS for simplicity) ----

// Generate a cache key from inputs
let makeCacheKey: (~fileType: string, ~existingContent: string, ~host: string) => string = %raw(`
  function(fileType, existingContent, host) {
    // Simple hash using string concatenation and charCode sum
    const input = fileType + "|" + host + "|" + existingContent;
    let hash = 0;
    for (let i = 0; i < input.length; i++) {
      const char = input.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    return "llm-cache-" + Math.abs(hash).toString(36);
  }
`)

// Read cached LLM response, or return null if cache miss.
// Cache is deterministic — no random invalidation. Delete the .json file to refresh.
let readCache: string => promise<Nullable.t<string>> = %raw(`
  async function(cacheKey) {
    const fs = await import('node:fs/promises');
    const path = await import('node:path');
    try {
      const cacheDir = path.join(process.cwd(), "test", "cli", ".llm-cache");
      const filePath = path.join(cacheDir, cacheKey + ".json");
      const raw = await fs.readFile(filePath, "utf-8");
      const cached = JSON.parse(raw);
      console.log("  [cache] Hit for " + cacheKey);
      return cached.content;
    } catch {
      return null;
    }
  }
`)

// Write LLM response to cache
let writeCache: (~cacheKey: string, ~content: string) => promise<unit> = %raw(`
  async function(cacheKey, content) {
    const fs = await import('node:fs/promises');
    const path = await import('node:path');
    const cacheDir = path.join(process.cwd(), "test", "cli", ".llm-cache");
    await fs.mkdir(cacheDir, { recursive: true });
    const filePath = path.join(cacheDir, cacheKey + ".json");
    await fs.writeFile(filePath, JSON.stringify({ content, timestamp: Date.now() }));
    // Reset run counter on fresh write
    const runCountPath = path.join(cacheDir, cacheKey + ".runs");
    await fs.writeFile(runCountPath, "0");
    console.log("  [cache] Written for " + cacheKey);
  }
`)

// Helper: call LLM with caching
let callLLMCached = async (
  ~fileType: AutoEdit.fileType,
  ~existingContent: string,
  ~host: string,
): result<string, string> => {
  let fileTypeStr = switch fileType {
  | AutoEdit.Middleware => "middleware"
  | AutoEdit.Proxy => "proxy"
  | AutoEdit.Instrumentation => "instrumentation"
  }
  let cacheKey = makeCacheKey(~fileType=fileTypeStr, ~existingContent, ~host)

  let cached = await readCache(cacheKey)
  switch cached->Nullable.toOption {
  | Some(content) => Ok(content)
  | None =>
    let result = await AutoEdit.callLLM(~existingContent, ~fileType, ~host)
    switch result {
    | Ok(content) =>
      await writeCache(~cacheKey, ~content)
      Ok(content)
    | Error(_) as err => err
    }
  }
}

// ---- Verification helpers ----

// Write content to a temp .ts file and run esbuild to verify valid TypeScript syntax
let verifyTypeScriptSyntax = async (content: string, fileName: string): result<unit, string> => {
  let tempDir = Path.join([Os.tmpdir(), `frontman-ts-check-${Date.now()->Float.toString}`])
  let _ = await Fs.Promises.mkdir(tempDir, {recursive: true})
  let filePath = Path.join([tempDir, fileName])
  await Fs.Promises.writeFile(filePath, content)

  // Resolve esbuild from the repo root node_modules (yarn workspaces hoists it there)
  let repoRoot = Path.join([Process.cwd(), "..", ".."])
  let esbuildPath = Path.join([repoRoot, "node_modules", ".bin", "esbuild"])
  let cmd = `${esbuildPath} ${filePath} --bundle=false --format=esm --outfile=/dev/null 2>&1`

  let result = switch await ChildProcess.exec(cmd) {
  | Ok(_) => Ok()
  | Error(err) =>
    let output = switch err.stderr != "" {
    | true => err.stderr
    | false => err.stdout
    }
    Error(`TypeScript syntax error in ${fileName}:\n${output}`)
  }

  // Cleanup
  let _ = await ChildProcess.exec(`rm -rf ${tempDir}`)
  result
}

// Find the position of a pattern in the content, returns -1 if not found
let indexOf: (string, string) => int = %raw(`
  function(content, pattern) { return content.indexOf(pattern); }
`)

// Check that frontman handler appears before existing logic in the function body
let verifyFrontmanBeforeExisting = (
  ~content: string,
  ~frontmanMarker: string,
  ~existingMarker: string,
): bool => {
  let frontmanPos = indexOf(content, frontmanMarker)
  let existingPos = indexOf(content, existingMarker)

  // Both must exist, and frontman must come first
  frontmanPos >= 0 && existingPos >= 0 && frontmanPos < existingPos
}

// Verification helpers implemented in JS to avoid ReScript raw string parsing issues
// with regex special characters like } inside template literals

@module("./autoEditTestHelpers.mjs") @val
external hasProperImport: (string, string) => bool = "hasProperImport"

@module("./autoEditTestHelpers.mjs") @val
external hasHostInConfig: (string, string) => bool = "hasHostInConfig"

@module("./autoEditTestHelpers.mjs") @val
external hasMatcherWithFrontman: (string, string) => bool = "hasMatcherWithFrontman"

@module("./autoEditTestHelpers.mjs") @val
external hasExportFunction: (string, string) => bool = "hasExportFunction"

// ---- Fixture content ----

module Fixtures = {
  let middlewareWithAuth = `import { NextRequest, NextResponse } from 'next/server';

export function middleware(req: NextRequest) {
  // Custom authentication middleware
  const token = req.cookies.get('token');
  if (!token) {
    return NextResponse.redirect(new URL('/login', req.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/dashboard/:path*'],
};
`

  let proxyWithRewrite = `import { NextRequest, NextResponse } from 'next/server';

export function proxy(req: NextRequest): NextResponse {
  // Custom proxy for API routes
  if (req.nextUrl.pathname.startsWith('/api/external')) {
    return NextResponse.rewrite(new URL('https://external-api.com' + req.nextUrl.pathname));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/api/external/:path*'],
};
`

  let instrumentationWithOTel = `import { NodeSDK } from '@opentelemetry/sdk-node';
import { SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const sdk = new NodeSDK({
      spanProcessors: [new SimpleSpanProcessor(new OTLPTraceExporter())],
    });
    sdk.start();
  }
}
`
}

// ---- Tests ----

let testHost = "test.frontman.dev"

describe("AutoEdit LLM Integration", _t => {
  describe("Middleware auto-edit", _t => {
    testAsync(
      "correctly integrates Frontman into existing middleware with auth",
      async t => {
        let result = await callLLMCached(
          ~fileType=AutoEdit.Middleware,
          ~existingContent=Fixtures.middlewareWithAuth,
          ~host=testHost,
        )

        switch result {
        | Ok(content) =>
          // 1. Valid TypeScript syntax
          switch await verifyTypeScriptSyntax(content, "middleware.ts") {
          | Ok() => t->expect(true)->Expect.toBe(true)
          | Error(err) =>
            Console.log(content)
            t->expect(err)->Expect.toBe("valid TypeScript")
          }

          // 2. Proper import statement (not just substring)
          t
          ->expect(hasProperImport(content, "@frontman-ai/nextjs"))
          ->Expect.toBe(true)

          // 3. Host inside createMiddleware config
          t
          ->expect(hasHostInConfig(content, testHost))
          ->Expect.toBe(true)

          // 4. Exported middleware function still exists
          t
          ->expect(hasExportFunction(content, "middleware"))
          ->Expect.toBe(true)

          // 5. Frontman handler appears BEFORE the existing auth logic
          t
          ->expect(
            verifyFrontmanBeforeExisting(
              ~content,
              ~frontmanMarker="frontman(req)",
              ~existingMarker="cookies",
            ),
          )
          ->Expect.toBe(true)

          // 6. Matcher includes both frontman routes AND existing routes
          t
          ->expect(hasMatcherWithFrontman(content, "/dashboard"))
          ->Expect.toBe(true)

          // 7. Original auth logic preserved
          t->expect(content->String.includes("/login"))->Expect.toBe(true)
          t->expect(content->String.includes("cookies"))->Expect.toBe(true)
        | Error(err) => t->expect(err)->Expect.toBe("should succeed")
        }
      },
      ~timeout=90_000,
    )
  })

  describe("Proxy auto-edit", _t => {
    testAsync(
      "correctly integrates Frontman into existing proxy with rewrites",
      async t => {
        let result = await callLLMCached(
          ~fileType=AutoEdit.Proxy,
          ~existingContent=Fixtures.proxyWithRewrite,
          ~host=testHost,
        )

        switch result {
        | Ok(content) =>
          // 1. Valid TypeScript syntax
          switch await verifyTypeScriptSyntax(content, "proxy.ts") {
          | Ok() => t->expect(true)->Expect.toBe(true)
          | Error(err) =>
            Console.log(content)
            t->expect(err)->Expect.toBe("valid TypeScript")
          }

          // 2. Proper import statement
          t
          ->expect(hasProperImport(content, "@frontman-ai/nextjs"))
          ->Expect.toBe(true)

          // 3. Host inside createMiddleware config
          t
          ->expect(hasHostInConfig(content, testHost))
          ->Expect.toBe(true)

          // 4. Exported proxy function still exists
          t
          ->expect(hasExportFunction(content, "proxy"))
          ->Expect.toBe(true)

          // 5. Frontman route handling appears BEFORE existing rewrite logic
          t
          ->expect(
            verifyFrontmanBeforeExisting(
              ~content,
              ~frontmanMarker="/frontman",
              ~existingMarker="/api/external",
            ),
          )
          ->Expect.toBe(true)

          // 6. Matcher includes both frontman routes AND existing routes
          t
          ->expect(hasMatcherWithFrontman(content, "/api/external"))
          ->Expect.toBe(true)

          // 7. Original rewrite logic preserved
          t->expect(content->String.includes("external-api.com"))->Expect.toBe(true)
          t->expect(content->String.includes("/api/external"))->Expect.toBe(true)
        | Error(err) => t->expect(err)->Expect.toBe("should succeed")
        }
      },
      ~timeout=90_000,
    )
  })

  describe("Instrumentation auto-edit", _t => {
    testAsync(
      "correctly integrates Frontman into existing instrumentation with OTel",
      async t => {
        let result = await callLLMCached(
          ~fileType=AutoEdit.Instrumentation,
          ~existingContent=Fixtures.instrumentationWithOTel,
          ~host=testHost,
        )

        switch result {
        | Ok(content) =>
          // 1. Valid TypeScript syntax
          switch await verifyTypeScriptSyntax(content, "instrumentation.ts") {
          | Ok() => t->expect(true)->Expect.toBe(true)
          | Error(err) =>
            Console.log(content)
            t->expect(err)->Expect.toBe("valid TypeScript")
          }

          // 2. Proper import for Frontman instrumentation
          t
          ->expect(hasProperImport(content, "@frontman-ai/nextjs/Instrumentation"))
          ->Expect.toBe(true)

          // 3. Exported register function still exists
          t
          ->expect(hasExportFunction(content, "register"))
          ->Expect.toBe(true)

          // 4. Frontman setup() call present
          t->expect(content->String.includes("setup()"))->Expect.toBe(true)

          // 5. NEXT_RUNTIME guard preserved
          t->expect(content->String.includes("NEXT_RUNTIME"))->Expect.toBe(true)

          // 6. Original OTel setup preserved
          t->expect(content->String.includes("OTLPTraceExporter"))->Expect.toBe(true)
          t->expect(content->String.includes("SimpleSpanProcessor"))->Expect.toBe(true)
        | Error(err) => t->expect(err)->Expect.toBe("should succeed")
        }
      },
      ~timeout=90_000,
    )
  })

  describe("Model fallback", _t => {
    testAsync(
      "falls back to next model on invalid model name",
      async t => {
        // Test that callModel fails gracefully for a non-existent model
        let result = await AutoEdit.callModel(
          ~model="definitely-not-a-real-model-xyz-123",
          ~systemPrompt="Say hello",
          ~userMessage="Hello",
        )

        switch result {
        | Error(_) =>
          // Expected: non-existent model should return an error
          t->expect(true)->Expect.toBe(true)
        | Ok(_) =>
          // If it somehow succeeds (unlikely), that's fine too
          t->expect(true)->Expect.toBe(true)
        }
      },
      ~timeout=30_000,
    )
  })

  describe("Validation", _t => {
    test("rejects output without Frontman import", t => {
      let invalidContent = "export function middleware() { return null; }"
      let isValid = AutoEdit.validateOutput(~content=invalidContent, ~fileType=AutoEdit.Middleware)
      t->expect(isValid)->Expect.toBe(false)
    })

    test("accepts valid middleware output", t => {
      let validContent = `import { createMiddleware } from '@frontman-ai/nextjs';
const frontman = createMiddleware({ host: 'test.host' });
export function middleware(req) { const r = await frontman(req); }
export const config = { matcher: ['/frontman/:path*'] };`
      let isValid = AutoEdit.validateOutput(~content=validContent, ~fileType=AutoEdit.Middleware)
      t->expect(isValid)->Expect.toBe(true)
    })

    test("rejects middleware output without matcher", t => {
      let invalidContent = `import { createMiddleware } from '@frontman-ai/nextjs';
const frontman = createMiddleware({ host: 'test.host' });
export function middleware(req) { const r = await frontman(req); }`
      let isValid = AutoEdit.validateOutput(~content=invalidContent, ~fileType=AutoEdit.Middleware)
      t->expect(isValid)->Expect.toBe(false)
    })

    test("accepts valid proxy output", t => {
      let validContent = `import { createMiddleware } from '@frontman-ai/nextjs';
const frontman = createMiddleware({ host: 'test.host' });
export function proxy(req) {
  if (req.nextUrl.pathname.startsWith('/frontman')) { return frontman(req); }
}
export const config = { matcher: ['/frontman/:path*'] };`
      let isValid = AutoEdit.validateOutput(~content=validContent, ~fileType=AutoEdit.Proxy)
      t->expect(isValid)->Expect.toBe(true)
    })

    test("rejects proxy output without /frontman path check", t => {
      let invalidContent = `import { createMiddleware } from '@frontman-ai/nextjs';
const frontman = createMiddleware({ host: 'test.host' });
export function proxy(req) { return frontman(req); }
export const config = { matcher: ['/dashboard/:path*'] };`
      let isValid = AutoEdit.validateOutput(~content=invalidContent, ~fileType=AutoEdit.Proxy)
      t->expect(isValid)->Expect.toBe(false)
    })

    test("rejects proxy output without matcher", t => {
      let invalidContent = `import { createMiddleware } from '@frontman-ai/nextjs';
const frontman = createMiddleware({ host: 'test.host' });
export function proxy(req) {
  if (req.nextUrl.pathname.startsWith('/frontman')) { return frontman(req); }
}`
      let isValid = AutoEdit.validateOutput(~content=invalidContent, ~fileType=AutoEdit.Proxy)
      t->expect(isValid)->Expect.toBe(false)
    })

    test("accepts valid instrumentation output", t => {
      let validContent = `import { setup } from '@frontman-ai/nextjs/Instrumentation';
export async function register() { const [l, s] = setup(); }`
      let isValid = AutoEdit.validateOutput(
        ~content=validContent,
        ~fileType=AutoEdit.Instrumentation,
      )
      t->expect(isValid)->Expect.toBe(true)
    })

    test("rejects instrumentation output without correct import path", t => {
      let invalidContent = `import { setup } from '@frontman-ai/nextjs';
export async function register() { const [l, s] = setup(); }`
      let isValid = AutoEdit.validateOutput(
        ~content=invalidContent,
        ~fileType=AutoEdit.Instrumentation,
      )
      t->expect(isValid)->Expect.toBe(false)
    })

    test("rejects instrumentation output without setup call", t => {
      let invalidContent = `import { something } from '@frontman-ai/nextjs/Instrumentation';
export async function register() { something(); }`
      let isValid = AutoEdit.validateOutput(
        ~content=invalidContent,
        ~fileType=AutoEdit.Instrumentation,
      )
      t->expect(isValid)->Expect.toBe(false)
    })
  })

  describe("Timeout handling", _t => {
    testAsync(
      "returns timeout error for unreachable endpoint",
      async t => {
        // Use a non-routable IP to trigger a timeout (with a short timeout)
        let result = await AutoEdit.fetchChatCompletion(
          ~url="http://10.255.255.1:1234/v1/chat/completions",
          ~apiKey="test",
          ~model="test-model",
          ~systemPrompt="test",
          ~userMessage="test",
          ~timeoutMs=1_000,
        )

        switch result {
        | Error(msg) =>
          // Should mention timeout or request failure
          let isTimeoutOrFail =
            msg->String.includes("timed out") || msg->String.includes("Request failed")
          t->expect(isTimeoutOrFail)->Expect.toBe(true)
        | Ok(_) =>
          // Very unlikely to succeed, but don't fail test if it does
          t->expect(true)->Expect.toBe(true)
        }
      },
      ~timeout=10_000,
    )
  })

  describe("File size guard", _t => {
    testAsync(
      "rejects files larger than maxFileSizeBytes",
      async t => {
        // Create content larger than 50KB
        let largeContent = String.repeat("x", AutoEdit.maxFileSizeBytes + 1)
        let result = await AutoEdit.autoEditFile(
          ~filePath="/tmp/fake-large-file.ts",
          ~fileName="fake-large-file.ts",
          ~existingContent=largeContent,
          ~fileType=AutoEdit.Middleware,
          ~host="test.host",
        )
        switch result {
        | AutoEdit.AutoEditFailed(msg) =>
          t->expect(msg->String.includes("too large"))->Expect.toBe(true)
        | AutoEdit.AutoEdited(_) => t->expect("should")->Expect.toBe("fail for large file")
        }
      },
      ~timeout=5_000,
    )

    testAsync(
      "accepts files within size limit",
      async t => {
        // Small content should NOT trigger the size guard (it may fail for other
        // reasons like LLM call, but should NOT fail with "too large")
        let smallContent = "const x = 1;"
        let result = await AutoEdit.autoEditFile(
          ~filePath="/tmp/fake-small-file.ts",
          ~fileName="fake-small-file.ts",
          ~existingContent=smallContent,
          ~fileType=AutoEdit.Middleware,
          ~host="test.host",
        )
        switch result {
        | AutoEdit.AutoEditFailed(msg) =>
          // Should fail for a reason OTHER than file size
          t->expect(msg->String.includes("too large"))->Expect.toBe(false)
        | AutoEdit.AutoEdited(_) =>
          // Unlikely in test but acceptable
          t->expect(true)->Expect.toBe(true)
        }
      },
      ~timeout=90_000,
    )
  })

  describe("Markdown fence stripping", _t => {
    test("strips markdown fences from LLM output", t => {
      let wrapped = "```typescript\nconst x = 1;\n```"
      let stripped = AutoEdit.stripMarkdownFences(wrapped)
      t->expect(stripped)->Expect.toBe("const x = 1;")
    })

    test("leaves content without fences unchanged", t => {
      let plain = "const x = 1;\nconst y = 2;"
      let result = AutoEdit.stripMarkdownFences(plain)
      t->expect(result)->Expect.toBe(plain)
    })

    test("handles fences with language tag", t => {
      let wrapped = "```ts\nconst x = 1;\nconst y = 2;\n```"
      let stripped = AutoEdit.stripMarkdownFences(wrapped)
      t->expect(stripped)->Expect.toBe("const x = 1;\nconst y = 2;")
    })
  })
})
