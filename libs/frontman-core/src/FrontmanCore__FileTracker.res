module Fs = FrontmanBindings.Fs

type range = {start: int, end_: int}

type fileRecord = {
  readAt: float,
  mtimeMs: float,
  size: float,
  ranges: array<range>,
  totalLines: int,
}

let readFiles: ref<Map.t<string, fileRecord>> = ref(Map.make())

let locks: ref<Map.t<string, promise<unit>>> = ref(Map.make())

let mergeRanges = (ranges: array<range>): array<range> => {
  switch ranges->Array.length {
  | 0 => []
  | _ =>
    let sorted = ranges->Array.toSorted((a, b) => Float.fromInt(a.start - b.start))
    let first = sorted->Array.getUnsafe(0)
    let rest = sorted->Array.slice(~start=1, ~end=sorted->Array.length)
    rest->Array.reduce([{start: first.start, end_: first.end_}], (merged, current) => {
      let lastIdx = merged->Array.length - 1
      let last = merged->Array.getUnsafe(lastIdx)
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

let recordRead = async (
  resolvedPath: string,
  ~offset: int,
  ~limit: int,
  ~totalLines: int,
): unit => {
  let stats = await Fs.Promises.stat(resolvedPath)
  let newRange = {start: offset, end_: min(offset + limit, totalLines)}
  let existingRanges = switch readFiles.contents->Map.get(resolvedPath) {
  | Some(existing) => existing.ranges
  | None => []
  }
  readFiles.contents->Map.set(
    resolvedPath,
    {
      readAt: Date.now(),
      mtimeMs: Fs.mtimeMs(stats),
      size: Fs.size(stats),
      totalLines,
      ranges: existingRanges->Array.concat([newRange])->mergeRanges,
    },
  )
}

let isLineCovered = (ranges: array<range>, line: int): bool => {
  ranges->Array.some(r => line >= r.start && line < r.end_)
}

let get = (resolvedPath: string): option<fileRecord> => {
  readFiles.contents->Map.get(resolvedPath)
}

let assertReadBefore = (resolvedPath: string): result<unit, string> => {
  switch readFiles.contents->Map.has(resolvedPath) {
  | true => Ok()
  | false =>
    Error(
      `File must be read before editing. Use read_file on "${resolvedPath}" first to see its current content.`,
    )
  }
}

let assertNotStale = async (resolvedPath: string): result<unit, string> => {
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
    | _ => Ok()
    }
  }
}

let checkCoverage = (resolvedPath: string, ~content: string, ~oldText: string): option<string> => {
  switch readFiles.contents->Map.get(resolvedPath) {
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
      | Some(line) =>
        switch isLineCovered(ranges, line) {
        | true => None
        | false =>
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
}

let assertEditSafe = async (resolvedPath: string): result<unit, string> => {
  switch assertReadBefore(resolvedPath) {
  | Error(_) as e => e
  | Ok() => await assertNotStale(resolvedPath)
  }
}

let recordWrite = async (resolvedPath: string): unit => {
  switch readFiles.contents->Map.get(resolvedPath) {
  | Some(record) =>
    let stats = await Fs.Promises.stat(resolvedPath)
    readFiles.contents->Map.set(
      resolvedPath,
      {
        ...record,
        readAt: Date.now(),
        mtimeMs: Fs.mtimeMs(stats),
        size: Fs.size(stats),
      },
    )
  | None => ()
  }
}

let withLock = async (resolvedPath: string, fn: unit => promise<unit>): unit => {
  let prev = locks.contents->Map.get(resolvedPath)->Option.getOr(Promise.resolve())
  let {promise: next, resolve} = Promise.withResolvers()
  locks.contents->Map.set(resolvedPath, next)
  await prev
  try {
    await fn()
    resolve()
  } catch {
  | exn =>
    resolve()
    throw(exn)
  }
  switch locks.contents->Map.get(resolvedPath) == Some(next) {
  | true => locks.contents->Map.delete(resolvedPath)->ignore
  | false => ()
  }
}

let clear = (): unit => {
  readFiles := Map.make()
  locks := Map.make()
}
