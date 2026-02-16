// AI-powered auto-edit for existing files during installation
// Uses OpenCode Zen API (free, no API key required) to merge Frontman into existing files

module Bindings = FrontmanBindings
module Fs = Bindings.Fs
module Readline = Bindings.Readline

module Templates = FrontmanAstro__Cli__Templates
module Style = FrontmanAstro__Cli__Style

type fileType =
  | Config
  | Middleware

// OpenCode Zen API configuration
let apiBaseUrl = "https://opencode.ai/zen/v1/chat/completions"
let apiKey = "public"

// Model fallback chain (all free on OpenCode Zen, no API key needed)
// Verified against https://opencode.ai/zen/v1/models
let models = ["gpt-5-nano", "big-pickle", "glm-4.7-free"]

// Build the system prompt for the LLM based on file type
let buildSystemPrompt = (~fileType: fileType, ~host: string): string => {
  let (typeName, manualInstructions, referenceTemplate, rules) = switch fileType {
  | Config => (
      "astro.config.mjs",
      Templates.ErrorMessages.configManualSetup("astro.config.mjs", host),
      Templates.configTemplate(host),
      `- Add the import for '@astrojs/node' at the top of the file
- Add the import for '@frontman-ai/astro' (frontmanIntegration) at the top of the file
- Add frontmanIntegration() to the integrations array
- Add SSR dev mode config: ...(isProd ? {} : { output: 'server', adapter: node({ mode: 'standalone' }) })
- Add const isProd = process.env.NODE_ENV === 'production'; before defineConfig
- Preserve ALL existing integrations and configuration unchanged
- Do not remove or modify any existing imports or settings`,
    )
  | Middleware => (
      "src/middleware.ts",
      Templates.ErrorMessages.middlewareManualSetup("src/middleware.ts", host),
      Templates.middlewareTemplate(host),
      `- Add the import for '@frontman-ai/astro' (createMiddleware, makeConfig) at the top of the file
- Add the import for 'astro:middleware' (defineMiddleware, sequence) at the top of the file
- Create a Frontman middleware instance with makeConfig({ host: '${host}' })
- Create a defineMiddleware wrapper for the Frontman handler
- Use sequence() to combine the Frontman middleware with the existing onRequest handler
- The Frontman middleware should come FIRST in the sequence
- Preserve ALL existing middleware functionality unchanged
- Do not remove or modify any existing imports or middleware logic`,
    )
  }

  `You are a code editor. Modify an Astro ${typeName} file to integrate Frontman.

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
  switch fileType {
  | Config =>
    content->String.includes("frontmanIntegration") &&
    content->String.includes("@frontman-ai/astro") &&
    content->String.includes("defineConfig")
  | Middleware =>
    content->String.includes("@frontman-ai/astro") &&
    content->String.includes("createMiddleware") &&
    content->String.includes("makeConfig") &&
    content->String.includes("onRequest")
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

// Main auto-edit function: call LLM, write file
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
