// Compare protocol schemas against the main branch to detect breaking changes.
// Run: node scripts/CheckBreakingChanges.res.mjs

module ChildProcess = FrontmanBindings.ChildProcess
module Path = FrontmanBindings.Path
module Fs = FrontmanBindings.Fs

@val @scope(("import", "meta"))
external importMetaUrl: string = "url"

@module("node:url")
external fileURLToPath: string => string = "fileURLToPath"

let schemasDir = Path.join([Path.dirname(fileURLToPath(importMetaUrl)), "..", "schemas"])

// Relative path from repo root to schemas dir
let schemasRelative = "libs/frontman-protocol/schemas"

@val @scope("process")
external exit: int => unit = "exit"

type changeKind = Added | Removed | Modified

type change = {
  file: string,
  kind: changeKind,
}

let main = async () => {
  // Get list of schema files changed vs main
  let diffResult = await ChildProcess.exec(
    `git diff --name-status main -- ${schemasRelative}/`,
  )

  let diffOutput = switch diffResult {
  | Ok({stdout}) => stdout
  | Error({code, stderr}) =>
    // Exit code 1 with empty stderr means no diff (clean)
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

  // Parse git diff output: "A\tpath", "D\tpath", "M\tpath", "R100\told\tnew"
  let changes =
    diffOutput
    ->String.trim
    ->String.split("\n")
    ->Array.flatMap(line => {
      let parts = line->String.split("\t")
      switch parts {
      | [status, oldFile, newFile]
        if status->String.startsWith("R") || status->String.startsWith("C") =>
        // Renames/copies are a removal of the old path + addition of the new path
        [{file: oldFile, kind: Removed}, {file: newFile, kind: Added}]
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

  // Show detailed diff for modified schemas
  if modified->Array.length > 0 {
    Console.log("=== Detailed Changes ===\n")
    for i in 0 to modified->Array.length - 1 {
      let change = modified->Array.getUnsafe(i)
      Console.log(`--- ${change.file} ---`)
      let detailResult = await ChildProcess.exec(
        `git diff main -- ${change.file}`,
      )
      switch detailResult {
      | Ok({stdout}) => Console.log(stdout)
      | Error(_) => Console.log("  (could not generate diff)")
      }
    }
  }

  // Fail CI on removed schemas (definitively breaking)
  if removed->Array.length > 0 {
    Console.error(
      `\nBREAKING: ${removed->Array.length->Int.toString} schema(s) removed. This will break clients on older SDK versions.`,
    )
    Console.error("If this is intentional, a reviewer must approve the PR.")
    exit(1)
  }

  // Warn on modifications (potentially breaking, needs human review)
  if modified->Array.length > 0 {
    Console.log(
      `\nWARNING: ${modified->Array.length->Int.toString} schema(s) modified. Review changes above for backwards compatibility.`,
    )
  }
}

main()->ignore
