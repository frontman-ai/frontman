// AI-powered auto-edit for existing files during installation
// Uses OpenCode Zen API (free, no API key required) to merge Frontman into existing files

module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Path = Bindings.Path
module Readline = Bindings.Readline

module Templates = FrontmanNextjs__Cli__Templates
module Style = FrontmanNextjs__Cli__Style

type fileType =
  | Middleware
  | Proxy
  | Instrumentation

// OpenCode Zen API configuration
let apiBaseUrl = "https://opencode.ai/zen/v1/chat/completions"
let apiKey = "public"

// Model fallback chain (all free on OpenCode Zen, no API key needed)
// Verified against https://opencode.ai/zen/v1/models
let models = ["gpt-5-nano", "big-pickle", "glm-4.7-free"]

// Build the system prompt for the LLM based on file type
let buildSystemPrompt = (~fileType: fileType, ~host: string): string => {
  let (typeName, manualInstructions, referenceTemplate, rules) = switch fileType {
  | Middleware => (
      "middleware.ts",
      Templates.ErrorMessages.middlewareManualSetup("middleware.ts", host),
      Templates.middlewareTemplate(host),
      `- Add the import for '@frontman-ai/nextjs' at the top of the file
- Create the frontman middleware instance with host: '${host}'
- Add the Frontman handler at the BEGINNING of the existing middleware function, before any existing logic
- Preserve ALL existing functionality unchanged - do not remove or modify any existing code
- Include '/frontman' and '/frontman/:path*' in the matcher config alongside existing matchers`,
    )
  | Proxy => (
      "proxy.ts",
      Templates.ErrorMessages.proxyManualSetup("proxy.ts", host),
      Templates.proxyTemplate(host),
      `- Add the import for '@frontman-ai/nextjs' at the top of the file
- Create the frontman middleware instance with host: '${host}'
- Add the Frontman path check at the BEGINNING of the existing proxy function, before any existing logic
- Include '/frontman' and '/frontman/:path*' in the matcher config alongside existing matchers
- Preserve ALL existing functionality unchanged - do not remove or modify any existing code`,
    )
  | Instrumentation => (
      "instrumentation.ts",
      Templates.ErrorMessages.instrumentationManualSetup("instrumentation.ts"),
      Templates.instrumentationTemplate(),
      `- Add the dynamic import for '@frontman-ai/nextjs/Instrumentation' inside the register() function
- Call setup() to get [logProcessor, spanProcessor] from the Frontman instrumentation module
- Add the Frontman processors to the NodeSDK configuration (logRecordProcessors and spanProcessors)
- If no OpenTelemetry setup exists, create a new NodeSDK instance with the Frontman processors
- If OpenTelemetry is already configured, merge the Frontman processors with existing ones
- Preserve ALL existing functionality unchanged - do not remove or modify any existing code
- Do NOT add createMiddleware or host config - this is an instrumentation file, not middleware`,
    )
  }

  `You are a code editor. Modify a Next.js ${typeName} file to integrate Frontman.

## What to add
${manualInstructions}

## Reference template (for a fresh file without any existing code):

${referenceTemplate}

## Rules
${rules}
- Return ONLY the complete file contents. No markdown fences, no explanations, no comments about changes.`
}

// Build the user message with the existing file content
let buildUserMessage = (~existingContent: string): string => {
  `Here is the existing file to modify:

${existingContent}`
}

// Per-model timeout in milliseconds (30 seconds)
let requestTimeoutMs = 30_000

// Raw JS fetch implementation for Node.js (avoids webapi module dependency)
let fetchChatCompletion: (
  ~url: string,
  ~apiKey: string,
  ~model: string,
  ~systemPrompt: string,
  ~userMessage: string,
  ~timeoutMs: int,
) => promise<result<string, string>> = %raw(`
  async function(url, apiKey, model, systemPrompt, userMessage, timeoutMs) {
    try {
      const response = await fetch(url, {
        method: "POST",
        signal: AbortSignal.timeout(timeoutMs),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer " + apiKey,
        },
        body: JSON.stringify({
          model: model,
          temperature: 0,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userMessage },
          ],
        }),
      });

      if (!response.ok) {
        return { TAG: "Error", _0: "HTTP " + response.status + ": " + response.statusText };
      }

      const json = await response.json();
      const content = json?.choices?.[0]?.message?.content?.trim();
      if (!content) {
        return { TAG: "Error", _0: "Empty response from model" };
      }
      return { TAG: "Ok", _0: content };
    } catch (err) {
      if (err?.name === "TimeoutError") {
        return { TAG: "Error", _0: "Request timed out after " + (timeoutMs / 1000) + "s" };
      }
      return { TAG: "Error", _0: "Request failed: " + (err?.message || "Unknown error") };
    }
  }
`)

// Call a single model
let callModel = async (
  ~model: string,
  ~systemPrompt: string,
  ~userMessage: string,
): result<string, string> => {
  await fetchChatCompletion(
    ~url=apiBaseUrl,
    ~apiKey,
    ~model,
    ~systemPrompt,
    ~userMessage,
    ~timeoutMs=requestTimeoutMs,
  )
}

// Strip markdown fences if the LLM wraps the response in them
let stripMarkdownFences = (content: string): string => {
  let lines = content->String.split("\n")
  let len = lines->Array.length

  // Check if first line is a markdown fence
  let firstLine = lines->Array.get(0)->Option.getOr("")
  let startsWithFence = firstLine->String.startsWith("```")

  switch startsWithFence {
  | false => content
  | true =>
    // Find last line that is a closing fence
    let lastLine = lines->Array.get(len - 1)->Option.getOr("")
    let endsWithFence = lastLine->String.trim == "```"

    let endIdx = switch endsWithFence {
    | true => len - 1
    | false => len
    }

    lines
    ->Array.slice(~start=1, ~end=endIdx)
    ->Array.join("\n")
  }
}

// Validate that the LLM output contains required Frontman imports/config
let validateOutput = (~content: string, ~fileType: fileType): bool => {
  let hasFrontmanImport = content->String.includes("@frontman-ai/nextjs")

  switch fileType {
  | Middleware =>
    hasFrontmanImport &&
    content->String.includes("createMiddleware") &&
    content->String.includes("frontman") &&
    content->String.includes("matcher")
  | Proxy =>
    hasFrontmanImport &&
    content->String.includes("createMiddleware") &&
    content->String.includes("frontman") &&
    content->String.includes("/frontman") &&
    content->String.includes("matcher")
  | Instrumentation =>
    hasFrontmanImport &&
    content->String.includes("@frontman-ai/nextjs/Instrumentation") &&
    content->String.includes("setup")
  }
}

// Call LLM with model fallback chain
let callLLM = async (
  ~existingContent: string,
  ~fileType: fileType,
  ~host: string,
): result<string, string> => {
  let systemPrompt = buildSystemPrompt(~fileType, ~host)
  let userMessage = buildUserMessage(~existingContent)

  let rec tryModels = async (remaining: array<string>, errors: array<string>) => {
    switch remaining->Array.get(0) {
    | None =>
      let allErrors = errors->Array.join("; ")
      Error(`All models failed: ${allErrors}`)
    | Some(model) =>
      let rest = remaining->Array.slice(~start=1, ~end=Array.length(remaining))
      Console.log(`     ${Style.dim(`Trying model: ${model}...`)}`)

      switch await callModel(~model, ~systemPrompt, ~userMessage) {
      | Ok(rawContent) =>
        let content = stripMarkdownFences(rawContent)
        switch validateOutput(~content, ~fileType) {
        | true => Ok(content)
        | false =>
          let err = `${model}: output validation failed (missing Frontman imports)`
          Console.log(`     ${Style.dim(err)}`)
          await tryModels(rest, errors->Array.concat([err]))
        }
      | Error(err) =>
        let errMsg = `${model}: ${err}`
        Console.log(`     ${Style.dim(errMsg)}`)
        await tryModels(rest, errors->Array.concat([errMsg]))
      }
    }
  }

  await tryModels(models, [])
}

// Prompt user for auto-edit with privacy disclosure (batched for multiple files)
let promptUserForAutoEdit = async (~fileNames: array<string>): bool => {
  // Skip prompt if not interactive (piped input)
  switch Readline.isTTY() {
  | false => false
  | true =>
    Console.log("")
    switch fileNames->Array.length {
    | 1 =>
      let fileName = fileNames->Array.getUnsafe(0)
      Console.log(
        `  ${Style.warn}  ${Style.bold(fileName)} exists but doesn't have Frontman configured.`,
      )
    | _ =>
      Console.log(
        `  ${Style.warn}  The following files exist but don't have Frontman configured:`,
      )
      fileNames->Array.forEach(fileName => {
        Console.log(`     ${Style.purple("•")} ${Style.bold(fileName)}`)
      })
    }
    Console.log(
      `     ${Style.dim("Your file contents will be sent to a public LLM (OpenCode Zen).")}`,
    )
    Console.log("")

    let answer = await Readline.question(`     Auto-edit using AI? ${Style.dim("[Y/n]")} `)

    // Ctrl+D (EOF) returns null — treat as decline (never auto-consent)
    switch answer->Nullable.toOption {
    | None => false
    | Some(raw) =>
      switch raw->String.trim->String.toLowerCase {
      | "" | "y" | "yes" => true
      | _ => false
      }
    }
  }
}

// Result type re-exported for use in Files.res
type autoEditResult =
  | AutoEdited(string)
  | AutoEditFailed(string)

// Maximum file size (in bytes) to send to the LLM. Files larger than this
// are skipped to avoid excessive latency or request failures.
let maxFileSizeBytes = 50_000

// Main auto-edit function: prompt user, call LLM, write file
let autoEditFile = async (
  ~filePath: string,
  ~fileName: string,
  ~existingContent: string,
  ~fileType: fileType,
  ~host: string,
): autoEditResult => {
  // Guard: skip files that are too large for reliable LLM editing
  let fileSize = existingContent->String.length
  switch fileSize > maxFileSizeBytes {
  | true =>
    AutoEditFailed(
      `${fileName} is too large (${(fileSize / 1000)->Int.toString}KB) for auto-edit — max ${(maxFileSizeBytes / 1000)->Int.toString}KB`,
    )
  | false =>
    Console.log("")
    Console.log(`  ${Style.purple("⟳")}  Merging Frontman into ${Style.bold(fileName)}...`)

    switch await callLLM(~existingContent, ~fileType, ~host) {
    | Ok(newContent) =>
      try {
        await Fs.Promises.writeFile(filePath, newContent)
        AutoEdited(fileName)
      } catch {
      | _ => AutoEditFailed(`Failed to write ${fileName}`)
      }
    | Error(err) => AutoEditFailed(err)
    }
  }
}
