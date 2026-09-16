module Fs = FrontmanBindings.Fs
module SafePath = FrontmanCore__SafePath

type range = {start: int, end_: int}

type fileRecord = {
  readAt: float,
  mtimeMs: float,
  size: float,
  ranges: array<range>,
  totalLines: int,
}

let readFiles: ref<Map.t<string, fileRecord>> = ref(Map.make())

let mergeRanges = (ranges: array<range>): array<range> => {
  switch ranges->Array.length {
  | 0 => []
  | _ =>
    let sorted = ranges->Array.toSorted((a, b) => Float.fromInt(a.start - b.start))
    let first = sorted->Array.get(0)->Option.getOrThrow
    let rest = sorted->Array.slice(~start=1, ~end=sorted->Array.length)
    rest->Array.reduce([{start: first.start, end_: first.end_}], (merged, current) => {
      let lastIdx = merged->Array.length - 1
      let last = merged->Array.get(lastIdx)->Option.getOrThrow
      switch current.start <= last.end_ {
      | true =>
        merged->Array.mapWithIndex((r, i) =>
          switch i == lastIdx {
          | true => {start: r.start, end_: max(r.end_, current.end_)}
          | false => r
          }
        )
      | false => merged->Array.concat([{start: current.start, end_: current.end_}])
      }
    })
  }
}

let recordRead = (
  safePath: SafePath.t,
  ~offset: int,
  ~limit: int,
  ~totalLines: int,
  ~mtimeMs: float,
  ~size: float,
): unit => {
  let resolvedPath = SafePath.toString(safePath)
  let newRange = {start: offset, end_: min(offset + limit, totalLines)}
  let existingRanges = switch readFiles.contents->Map.get(resolvedPath) {
  | Some(existing) => existing.ranges
  | None => []
  }
  readFiles.contents->Map.set(
    resolvedPath,
    {
      readAt: Date.now(),
      mtimeMs,
      size,
      totalLines,
      ranges: existingRanges->Array.concat([newRange])->mergeRanges,
    },
  )
}

let isLineCovered = (ranges: array<range>, line: int): bool => {
  ranges->Array.some(r => line >= r.start && line < r.end_)
}

let get = (safePath: SafePath.t): option<fileRecord> => {
  readFiles.contents->Map.get(SafePath.toString(safePath))
}

let assertReadBefore = (safePath: SafePath.t): result<unit, string> => {
  let resolvedPath = SafePath.toString(safePath)
  switch readFiles.contents->Map.has(resolvedPath) {
  | true => Ok()
  | false =>
    Error(
      `File must be read before editing. Use read_file on "${resolvedPath}" first to see its current content.`,
    )
  }
}

let assertNotStale = async (safePath: SafePath.t): result<unit, string> => {
  let resolvedPath = SafePath.toString(safePath)
  switch readFiles.contents->Map.get(resolvedPath) {
  | None => Ok()
  | Some(record) =>
    try {
      let stats = await Fs.Promises.stat(resolvedPath)
      let currentMtime = Fs.mtimeMs(stats)
      let currentSize = Fs.size(stats)
      switch currentMtime != record.mtimeMs || currentSize != record.size {
      | true =>
        Error(
          `File "${resolvedPath}" has been modified since it was last read. Please read the file again before editing.`,
        )
      | false => Ok()
      }
    } catch {
    | exn =>
      let msg =
        exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("unknown error")
      Error(`File "${resolvedPath}" is no longer accessible: ${msg}`)
    }
  }
}

let checkCoverage = (safePath: SafePath.t, ~content: string, ~oldText: string): option<string> => {
  switch readFiles.contents->Map.get(SafePath.toString(safePath)) {
  | None => None
  | Some(record) =>
    switch record.ranges {
    | [{start: 0, end_}] if end_ >= record.totalLines => None
    | ranges =>
      let lines = content->String.split("\n")
      let firstOldLine =
        oldText->String.trim->String.split("\n")->Array.get(0)->Option.getOr("")->String.trim

      let targetLine = lines->Array.findIndexOpt(line => line->String.trim == firstOldLine)

      switch targetLine {
      | None => None
      | Some(line) if isLineCovered(ranges, line) => None
      | Some(line) =>
        let rangeStr =
          ranges
          ->Array.map(r => `${Int.toString(r.start)}-${Int.toString(r.end_)}`)
          ->Array.join(", ")
        Some(
          `Warning: You are editing around line ${Int.toString(
              line,
            )} but only read lines [${rangeStr}] of this ${Int.toString(
              record.totalLines,
            )}-line file. Consider reading the target section first with read_file and an appropriate offset.`,
        )
      }
    }
  }
}

let assertEditSafe = async (safePath: SafePath.t): result<unit, string> => {
  switch assertReadBefore(safePath) {
  | Error(_) as e => e
  | Ok() => await assertNotStale(safePath)
  }
}

let recordWrite = (safePath: SafePath.t, ~mtimeMs: float, ~size: float): unit => {
  let resolvedPath = SafePath.toString(safePath)
  switch readFiles.contents->Map.get(resolvedPath) {
  | Some(record) =>
    readFiles.contents->Map.set(
      resolvedPath,
      {
        ...record,
        readAt: Date.now(),
        mtimeMs,
        size,
      },
    )
  | None => ()
  }
}

let clear = (): unit => {
  readFiles := Map.make()
}
