module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs
module CP = FrontmanBindings.ChildProcess

let exec = async (command: string): result<CP.execResult, CP.execError> => {
  await Promise.make((resolve, _reject) => {
    CP.nodeExec(command, {encoding: "utf8", maxBuffer: 50 * 1024 * 1024}, (err, stdout, stderr) => {
      switch err->Nullable.toOption {
      | None => resolve(Ok({CP.stdout, stderr}))
      | Some(execErr) =>
        resolve(
          Error({
            CP.code: execErr->CP.execExceptionCode->Nullable.toOption,
            stdout,
            stderr,
            message: execErr->CP.execExceptionMessage,
          }),
        )
      }
    })
  })
}

@val @scope(("import", "meta"))
external importMetaUrl: string = "url"

@module("node:url")
external fileURLToPath: string => string = "fileURLToPath"

let schemasDir = Path.join([Path.dirname(fileURLToPath(importMetaUrl)), "..", "schemas"])

let schemasRelative = "libs/frontman-protocol/schemas"
let protocolPackage = "\"@frontman-ai/frontman-protocol\": major"

@val @scope("process")
external exit: int => unit = "exit"

type changeKind = Added | Removed | Modified

type change = {
  file: string,
  kind: changeKind,
}

let main = async () => {
  let diffResult = await exec(`git diff --name-status origin/main -- ${schemasRelative}/`)

  let diffOutput = switch diffResult {
  | Ok({stdout}) => stdout
  | Error({code, stderr}) =>
    if code == Some(1) && stderr == "" {
      ""
    } else {
      Console.error(`Failed to diff against main: ${stderr}`)
      exit(1)
      ""
    }
  }

  if diffOutput->String.trim == "" {
    Console.log("No protocol schema changes detected.")
    exit(0)
  }

  let changes =
    diffOutput
    ->String.trim
    ->String.split("\n")
    ->Array.flatMap(line => {
      let parts = line->String.split("\t")
      switch parts {
      | [status, oldFile, newFile]
        if status->String.startsWith("R") || status->String.startsWith("C") => [
          {file: oldFile, kind: Removed},
          {file: newFile, kind: Added},
        ]
      | [status, file] =>
        let kind = switch status {
        | "A" => Added
        | "D" => Removed
        | "M" => Modified
        | _ => Modified
        }
        [{file, kind}]
      | _ => []
      }
    })

  let added = changes->Array.filter(c => c.kind == Added)
  let removed = changes->Array.filter(c => c.kind == Removed)
  let modified = changes->Array.filter(c => c.kind == Modified)

  Console.log("=== Protocol Schema Change Report ===\n")

  if added->Array.length > 0 {
    Console.log(`Added (non-breaking):`)
    added->Array.forEach(c => Console.log(`  + ${c.file}`))
    Console.log("")
  }

  if modified->Array.length > 0 {
    Console.log(`Modified (review required):`)
    modified->Array.forEach(c => Console.log(`  ~ ${c.file}`))
    Console.log("")
  }

  if removed->Array.length > 0 {
    Console.log(`Removed (BREAKING):`)
    removed->Array.forEach(c => Console.log(`  - ${c.file}`))
    Console.log("")
  }

  if modified->Array.length > 0 {
    Console.log("=== Detailed Changes ===\n")
    for i in 0 to modified->Array.length - 1 {
      let change = modified->Array.getUnsafe(i)
      Console.log(`--- ${change.file} ---`)
      let detailResult = await exec(`git diff origin/main -- ${change.file}`)
      switch detailResult {
      | Ok({stdout}) => Console.log(stdout)
      | Error(_) => Console.log("  (could not generate diff)")
      }
    }
  }

  let protocolMajorDeclared = switch removed->Array.length > 0 {
  | true =>
    switch await exec("git diff origin/main -- .changeset/") {
    | Ok({stdout}) => stdout->String.split("\n")->Array.some(line => line == `+${protocolPackage}`)
    | Error({stderr}) =>
      Console.error(`Failed to inspect changesets: ${stderr}`)
      exit(1)
      false
    }
  | false => false
  }

  if removed->Array.length > 0 && !protocolMajorDeclared {
    Console.error(
      `\nBREAKING: ${removed
        ->Array.length
        ->Int.toString} schema(s) removed. This will break clients on older SDK versions.`,
    )
    Console.error(
      "Declare a major @frontman-ai/frontman-protocol changeset if this is intentional.",
    )
    exit(1)
  }

  if removed->Array.length > 0 {
    Console.log("Breaking schema removals accepted by major protocol changeset.")
  }

  if modified->Array.length > 0 {
    Console.log(
      `\nWARNING: ${modified
        ->Array.length
        ->Int.toString} schema(s) modified. Review changes above for backwards compatibility.`,
    )
  }
}

main()->ignore
