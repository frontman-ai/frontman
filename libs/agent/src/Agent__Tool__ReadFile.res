module Bindings = AskTheLlmBindings

@get external getErrorCode: JsExn.t => option<string> = "code"

let name = "read_file"
let description = `
Reads a text file from the local filesystem with line-based pagination. You can access any file directly by using this tool.

Usage:
- The 'path' parameter can be either absolute or relative to the projectRoot
- By default, reads up to 2000 lines starting from the beginning of the file
- Use 'offset' parameter to start reading from a specific line number (0-based)
- Use 'limit' parameter to control how many lines to read (default: 2000)
- Lines longer than 2000 characters are automatically truncated with "..." suffix
- Results are returned with line numbers (5-digit format) and a preview of the first ~20 lines
- Binary files (images, PDFs, executables, etc.) are detected and rejected with a clear error
- If a file is not found, the tool suggests similar file names from the parent directory
- Empty files are handled gracefully
- You can call multiple tools in a single response - read multiple files in parallel when useful

Output format:
- content: Full formatted file content with line numbers
- preview: First ~20 lines for quick preview
- totalLines: Total number of lines in the file
- hasMore: Boolean indicating if there are more lines beyond the current range

Examples:
- Read beginning of file: {path: "src/main.res"}
- Read from line 100: {path: "README.md", offset: 100}
- Read specific range: {path: "package.json", offset: 0, limit: 50}
`

let defaultReadLimit = 2000
let maxLineLength = 2000
let binaryDetectionBufferSize = 4096

@schema
type input = {
  path: string,
  offset: @s.default(0) int,
  limit: @s.default(defaultReadLimit) int,
}

@schema
type output = {
  content: string,
  preview: string,
  totalLines: int,
  hasMore: bool,
}

let isBinaryExtension = (filePath: string): bool => {
  let ext = Bindings.Path.extname(filePath)->String.toLowerCase

  switch ext {
  | ".zip" | ".tar" | ".gz" | ".7z" => true
  | ".exe" | ".dll" | ".so" | ".dylib" => true
  | ".class" | ".jar" | ".war" => true
  | ".pdf" | ".doc" | ".docx" | ".xls" | ".xlsx" | ".ppt" | ".pptx" => true
  | ".odt" | ".ods" | ".odp" => true
  | ".bin" | ".dat" | ".o" | ".obj" | ".a" | ".lib" => true
  | ".wasm" | ".pyc" | ".pyo" => true
  | ".png" | ".jpg" | ".jpeg" | ".gif" | ".bmp" | ".webp" => true
  | _ => false
  }
}

let checkIfBinary = async (filePath: string): result<bool, exn> => {
  let getFileStat = async (filePath: string): result<Bindings.Fs.stats, exn> => {
    try {
      let stats = await Bindings.Fs.Promises.stat(filePath)
      Ok(stats)
    } catch {
    | exn => Error(exn)
    }
  }
  let readFileAsBuffer = async (filePath: string, size: int): result<Uint8Array.t, exn> => {
    try {
      let buffer = await Bindings.Fs.Promises.readFileBuffer(filePath)
      let bytes = Bindings.TypedArrays.fromBuffer(buffer)
      let byteLength = Bindings.TypedArrays.length(bytes)
      let length = if size < byteLength {
        size
      } else {
        byteLength
      }
      Ok(Bindings.TypedArrays.slice(bytes, ~start=0, ~end=length))
    } catch {
    | exn => Error(exn)
    }
  }
  let isBinaryContent = (bytes: Uint8Array.t): bool => {
    let length = Bindings.TypedArrays.length(bytes)

    let byteArray = Array.fromInitializer(~length, i => Bindings.TypedArrays.unsafeGet(bytes, i))

    let hasNullByte = byteArray->Array.some(byte => byte == 0)

    if hasNullByte {
      true
    } else {
      let nonPrintableCount =
        byteArray
        ->Array.filter(byte => byte < 9 || (byte > 13 && byte < 32))
        ->Array.length

      let ratio = Int.toFloat(nonPrintableCount) /. Int.toFloat(length)
      ratio > 0.3
    }
  }

  // Quick check by extension first (no I/O needed)
  if isBinaryExtension(filePath) {
    Ok(true)
  } else {
    // Content-based detection using result chaining
    let statResult = await getFileStat(filePath)

    switch statResult {
    | Error(err) => Error(err)
    | Ok(stats) => {
        let fileSize = Bindings.Fs.size(stats)

        if fileSize == 0.0 {
          Ok(false) // Empty file is not binary
        } else {
          let bufferSizeFloat = binaryDetectionBufferSize->Int.toFloat
          let minSize = if bufferSizeFloat < fileSize {
            bufferSizeFloat
          } else {
            fileSize
          }
          let bufferSize = Int.fromFloat(minSize)
          let bufferResult = await readFileAsBuffer(filePath, bufferSize)

          switch bufferResult {
          | Error(err) => Error(err)
          | Ok(bytes) => Ok(isBinaryContent(bytes))
          }
        }
      }
    }
  }
}

// Safe file reading - converts exceptions to results

// Safe directory reading - converts exceptions to results
let readDirectory = async (dirPath: string): result<array<string>, exn> => {
  try {
    let entries = await Bindings.Fs.Promises.readdir(dirPath)
    Ok(entries)
  } catch {
  | exn => Error(exn)
  }
}

// Helper to check if exception has a specific error code
let hasErrorCode = (exn: exn, code: string): bool => {
  exn->JsExn.fromException->Option.flatMap(getErrorCode) == Some(code)
}

// Find similar file names in directory - returns result
let findSimilarFiles = async (filePath: string): result<array<string>, string> => {
  let dir = Bindings.Path.dirname(filePath)
  let base = Bindings.Path.basename(filePath)->String.toLowerCase

  let dirResult = await readDirectory(dir)

  switch dirResult {
  | Error(_) => Ok([]) // If can't read directory, return empty suggestions (not an error)
  | Ok(entries) => {
      let suggestions =
        entries
        ->Array.filter(entry => {
          let entryLower = entry->String.toLowerCase
          // Match if either contains the other (case-insensitive)
          entryLower->String.includes(base) || base->String.includes(entryLower)
        })
        ->Array.map(entry => Bindings.Path.join([dir, entry]))
        ->Array.slice(~start=0, ~end=3) // Top 3 suggestions

      Ok(suggestions)
    }
  }
}

// Format error message for file not found
let formatFileNotFoundError = async (relativePath: string, fullPath: string): string => {
  let suggestionsResult = await findSimilarFiles(fullPath)

  switch suggestionsResult {
  | Error(_) =>
    // Couldn't get suggestions, return generic message
    `File not found: "${relativePath}". ` ++
    `The file does not exist in the project. ` ++ `Use list_files to explore the directory structure and find the correct path.`
  | Ok(suggestions) if Array.length(suggestions) > 0 => {
      let suggestionList =
        suggestions
        ->Array.map(s => `- ${s}`)
        ->Array.join("\n")

      `File not found: "${relativePath}"\n\nDid you mean one of these?\n${suggestionList}`
    }
  | Ok(_) =>
    // No suggestions found
    `File not found: "${relativePath}". ` ++
    `The file does not exist in the project. ` ++ `Use list_files to explore the directory structure and find the correct path.`
  }
}

let decodeInput: JSON.t => result<input, S.error> = json => {
  try {
    Ok(json->S.parseOrThrow(inputSchema))
  } catch {
  | S.Error(error) => Error(error)
  }
}

let encodeOutput = (output: output): JSON.t => {
  output->S.reverseConvertOrThrow(outputSchema)->Obj.magic
}

// Resolve path to absolute - handles both relative and absolute paths
let resolvePath = (projectRoot: string, userPath: string): string => {
  // Check if path is already absolute (starts with / on Unix or C:\ on Windows)
  let isAbsolute =
    userPath->String.startsWith("/") ||
      (userPath->String.length > 1 && userPath->String.charAt(1) == ":")

  if isAbsolute {
    userPath
  } else {
    Bindings.Path.join([projectRoot, userPath])
  }
}

// Format a single line with line number
let formatLine = (lineNum: int, content: string): string => {
  let truncated = if String.length(content) > maxLineLength {
    String.slice(content, ~start=0, ~end=maxLineLength) ++ "..."
  } else {
    content
  }

  // Pad line number to 5 digits
  let lineNumStr = Int.toString(lineNum)->String.padStart(5, "0")
  `${lineNumStr}| ${truncated}`
}

// Format multiple lines
let formatLines = (lines: array<string>, startLineNum: int): string => {
  lines
  ->Array.mapWithIndex((line, idx) => formatLine(startLineNum + idx + 1, line))
  ->Array.join("\n")
}

// Create preview (first ~20 lines)
let createPreview = (lines: array<string>): string => {
  lines->Array.slice(~start=0, ~end=20)->Array.join("\n")
}

// Build output record from lines and params
let buildOutput = (
  selectedLines: array<string>,
  offset: int,
  totalLines: int,
  endLine: int,
): output => {
  let formattedContent = formatLines(selectedLines, offset)
  let hasMore = endLine < totalLines

  let content = if hasMore {
    `<file>\n${formattedContent}\n\n(File has more lines. Use 'offset' parameter to read beyond line ${Int.toString(
        endLine,
      )})\n</file>`
  } else {
    `<file>\n${formattedContent}\n</file>`
  }

  let preview = createPreview(selectedLines)

  {
    content,
    preview,
    totalLines,
    hasMore,
  }
}

// Process file content into output - returns result for validation
let processFileContent = (fileContent: string, offset: int, limit: int): result<output, string> => {
  let allLines = fileContent->String.split("\n")
  // Remove trailing empty line if it exists (from files ending with \n)
  let allLines = if Array.length(allLines) > 1 {
    let lastIdx = Array.length(allLines) - 1
    switch allLines[lastIdx] {
    | Some("") => allLines->Array.slice(~start=0, ~end=lastIdx)
    | _ => allLines
    }
  } else {
    allLines
  }
  let totalLines = Array.length(allLines)

  // Validate offset - return error if beyond file length
  if totalLines > 0 && offset >= totalLines {
    Error(`Offset ${Int.toString(offset)} is beyond file length. File has ${Int.toString(totalLines)} lines (0-${Int.toString(totalLines - 1)}).`)
  } else {
    let validOffset = if offset < 0 {
      0
    } else if totalLines == 0 {
      0
    } else {
      offset
    }

    // Validate and clamp limit
    let validLimit = if limit < 1 {
      1
    } else {
      limit
    }

    // Extract requested range
    let endLine = if validOffset + validLimit < totalLines {
      validOffset + validLimit
    } else {
      totalLines
    }
    let selectedLines = allLines->Array.slice(~start=validOffset, ~end=endLine)

    // Build output
    Ok(buildOutput(selectedLines, validOffset, totalLines, endLine))
  }
}

let execute = async (ctx: Agent__ToolExecutionContext.t, input: input): Agent__Tool.toolResult<
  output,
> => {
  let readFileAsText = async (filePath: string): result<string, exn> => {
    try {
      let content = await Bindings.Fs.Promises.readFile(filePath)
      Ok(content)
    } catch {
    | exn => Error(exn)
    }
  }
  let fullPath = resolvePath(ctx.projectRoot, input.path)
  let binaryCheckResult = await checkIfBinary(fullPath)

  switch binaryCheckResult {
  | Error(exn) if hasErrorCode(exn, "ENOENT") => {
      let errorMsg = await formatFileNotFoundError(input.path, fullPath)
      Error(errorMsg)
    }
  | Error(exn) if hasErrorCode(exn, "EISDIR") =>
    Error(
      `Cannot read "${input.path}" because it's a directory, not a file. ` ++ `Use list_files to see the contents of this directory.`,
    )
  | Error(exn) => {
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")
      Error(`Failed to check file: ${message}`)
    }
  | Ok(true) =>
    Error(`Cannot read binary file: "${input.path}". Use a binary file viewer or conversion tool.`)
  | Ok(false) => {
      // Step 2: Read file as text (file existence already verified by binary check)
      let readResult = await readFileAsText(fullPath)

      switch readResult {
      | Error(exn) => {
          let message =
            exn
            ->JsExn.fromException
            ->Option.flatMap(JsExn.message)
            ->Option.getOr("Unknown error")
          Error(`Failed to read file ${input.path}: ${message}`)
        }
      | Ok(fileContent) =>
          // Step 3: Process content into formatted output
          processFileContent(fileContent, input.offset, input.limit)
      }
    }
  }
}