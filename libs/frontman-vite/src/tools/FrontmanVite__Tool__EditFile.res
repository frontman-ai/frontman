// Vite-enhanced EditFile tool
//
// Wraps the core edit_file tool and checks dev server logs for compilation
// errors 800ms after the edit. This gives Vite's HMR time to process the
// change and report any issues.

module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool
module Core = FrontmanAiFrontmanCore
module CoreEditFile = Core.FrontmanCore__Tool__EditFile
module LogCapture = Core.FrontmanCore__LogCapture

let name = "edit_file"
let visibleToAgent = true
let description = CoreEditFile.description

type input = CoreEditFile.input
type output = CoreEditFile.output

let inputSchema = CoreEditFile.inputSchema
let outputSchema = CoreEditFile.outputSchema

// Wait for a given number of milliseconds
let sleep = (ms: int): promise<unit> => {
  Promise.make((resolve, _) => {
    let _ = setTimeout(() => resolve(), ms)
  })
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  // Record timestamp before the edit
  let beforeTimestamp = Date.now()

  // Run the core edit
  let result = await CoreEditFile.execute(ctx, input)

  switch result {
  | Error(_) => result // Edit failed, return error as-is
  | Ok(output) =>
    // Wait 800ms for Vite HMR to process the change
    await sleep(800)

    // Check for errors in logs since the edit
    // Query by level=Error and by error-related patterns separately,
    // then deduplicate since an Error-level log mentioning "error" appears in both
    let recentLogs = LogCapture.getLogs(~since=beforeTimestamp, ~level=Error)
    let errorLogs =
      LogCapture.getLogs(~since=beforeTimestamp, ~pattern="error|Error|failed|Failed")

    let seen = Set.make()
    recentLogs->Array.forEach(entry => seen->Set.add(entry.timestamp ++ "|" ++ entry.message))
    let allErrors = Array.concat(
      recentLogs,
      errorLogs->Array.filter(entry =>
        !(seen->Set.has(entry.timestamp ++ "|" ++ entry.message))
      ),
    )

    switch allErrors->Array.length > 0 {
    | false => Ok(output)
    | true =>
      let errorMessages =
        allErrors
        ->Array.slice(~start=0, ~end=5)
        ->Array.map(entry => entry.message)
        ->Array.join("\n")
      Ok({
        ...output,
        message: output.message ++
        `\n\nWarning: Dev server errors detected after edit:\n${errorMessages}`,
      })
    }
  }
}
