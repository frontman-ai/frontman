// FileTracker - Ensures files are read before being edited
//
// Records which files have been read (by resolved absolute path) along with:
// - readAt: timestamp of the last read (ms since epoch)
// - ranges: which line ranges were read (0-indexed start/end pairs)
//
// Provides assertions for:
// - read-before-edit: file must have been read before editing
// - staleness: file must not have been modified on disk since last read
// - coverage: warns when editing lines outside the read ranges

module Fs = FrontmanBindings.Fs

type range = {start: int, mutable end_: int}

type fileRecord = {
  mutable readAt: float,
  mutable ranges: array<range>,
  mutable totalLines: int,
}

// Global mutable map of read file paths -> file records
let readFiles: ref<Map.t<string, fileRecord>> = ref(Map.make())

// Merge overlapping/adjacent ranges into a sorted minimal set
let mergeRanges = (ranges: array<range>): array<range> => {
  switch ranges->Array.length {
  | 0 => []
  | _ =>
    let sorted = ranges->Array.toSorted((a, b) => Float.fromInt(a.start - b.start))
    let first = sorted->Array.getUnsafe(0)
    let merged = [{start: first.start, end_: first.end_}]
    for i in 1 to sorted->Array.length - 1 {
      let current = sorted->Array.getUnsafe(i)
      let last = merged->Array.getUnsafe(merged->Array.length - 1)
      if current.start <= last.end_ {
        // Overlapping or adjacent — extend
        last.end_ = max(last.end_, current.end_)
      } else {
        let _ = merged->Array.push({start: current.start, end_: current.end_})
      }
    }
    merged
  }
}

// Record that a file was read (called by ReadFile after successful read)
let recordRead = (
  resolvedPath: string,
  ~offset: int,
  ~limit: int,
  ~totalLines: int,
): unit => {
  let now = Date.now()
  let newRange = {start: offset, end_: min(offset + limit, totalLines)}

  switch readFiles.contents->Map.get(resolvedPath) {
  | Some(record) =>
    record.readAt = now
    record.totalLines = totalLines
    // Merge the new range into existing ranges
    record.ranges = record.ranges->Array.concat([newRange])->mergeRanges
  | None =>
    readFiles.contents->Map.set(
      resolvedPath,
      {
        readAt: now,
        ranges: [newRange],
        totalLines,
      },
    )
  }
}

// Check if a line number falls within any recorded read range
let isLineCovered = (ranges: array<range>, line: int): bool => {
  ranges->Array.some(r => line >= r.start && line < r.end_)
}

// Get the record for a file (if it exists)
let get = (resolvedPath: string): option<fileRecord> => {
  readFiles.contents->Map.get(resolvedPath)
}

// Assert a file was read before editing. Returns Error if not.
let assertReadBefore = (resolvedPath: string): result<unit, string> => {
  switch readFiles.contents->Map.has(resolvedPath) {
  | true => Ok()
  | false =>
    Error(
      `File must be read before editing. Use read_file on "${resolvedPath}" first to see its current content.`,
    )
  }
}

// Assert a file has not been modified on disk since the last read.
// Compares the file's mtime against the recorded readAt timestamp.
// Allows 100ms tolerance for filesystem flush delays.
let assertNotStale = async (resolvedPath: string): result<unit, string> => {
  switch readFiles.contents->Map.get(resolvedPath) {
  | None => Ok() // No record means assertReadBefore will catch it
  | Some(record) =>
    try {
      let stats = await Fs.Promises.stat(resolvedPath)
      let mtimeMs = Fs.mtimeMs(stats)
      let tolerance = 100.0 // ms — accounts for filesystem flush delays
      switch mtimeMs > record.readAt +. tolerance {
      | true =>
        Error(
          `File "${resolvedPath}" has been modified since it was last read. Please read the file again before editing.`,
        )
      | false => Ok()
      }
    } catch {
    | _ => Ok() // stat failure — let downstream handle missing file
    }
  }
}

// Check coverage: returns a warning string if the edit target appears
// to be outside the recorded read ranges. Not a hard block.
let checkCoverage = (
  resolvedPath: string,
  ~content: string,
  ~oldText: string,
): option<string> => {
  switch readFiles.contents->Map.get(resolvedPath) {
  | None => None
  | Some(record) =>
    // If the full file was read, no warning needed
    switch record.ranges {
    | [{start: 0, end_}] if end_ >= record.totalLines => None
    | ranges =>
      // Find which line the oldText starts at in the file
      let lines = content->String.split("\n")
      let oldLines = oldText->String.trim->String.split("\n")
      let firstOldLine = oldLines->Array.get(0)->Option.getOr("")->String.trim

      // Search for the first line of oldText in the file
      let targetLine = ref(None)
      lines->Array.forEachWithIndex((line, idx) => {
        switch targetLine.contents {
        | Some(_) => () // already found
        | None =>
          if line->String.trim == firstOldLine {
            targetLine := Some(idx)
          }
        }
      })

      switch targetLine.contents {
      | None => None // Can't determine target line — let the edit proceed
      | Some(line) =>
        switch isLineCovered(ranges, line) {
        | true => None // Target line is within a read range — all good
        | false =>
          let rangeStr =
            ranges
            ->Array.map(r => `${Int.toString(r.start)}-${Int.toString(r.end_)}`)
            ->Array.join(", ")
          Some(
            `Warning: You are editing around line ${Int.toString(line)} but only read lines [${rangeStr}] of this ${Int.toString(record.totalLines)}-line file. Consider reading the target section first with read_file and an appropriate offset.`,
          )
        }
      }
    }
  }
}

// Combined guard: file must have been read AND must not be stale.
// Names the domain concept "is it safe to edit this file?" so callers
// don't need to chain assertReadBefore + assertNotStale themselves.
let assertEditSafe = async (resolvedPath: string): result<unit, string> => {
  switch assertReadBefore(resolvedPath) {
  | Error(_) as e => e
  | Ok() => await assertNotStale(resolvedPath)
  }
}

// Record that a file was written (called by EditFile/WriteFile after successful write).
// Updates readAt so that subsequent staleness checks don't reject the agent's own edits.
let recordWrite = (resolvedPath: string): unit => {
  switch readFiles.contents->Map.get(resolvedPath) {
  | Some(record) => record.readAt = Date.now()
  | None => () // No record — shouldn't happen since we require read-before-edit
  }
}

// Clear all tracked reads (useful for testing)
let clear = (): unit => {
  readFiles := Map.make()
}
