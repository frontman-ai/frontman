// Tests for FileTracker - read tracking, staleness, and coverage checks

open Vitest

module FileTracker = FrontmanCore__FileTracker

// ============================================
// Setup: clear state between tests
// ============================================

beforeEach(_t => {
  FileTracker.clear()
})

// ============================================
// mergeRanges
// ============================================

describe("mergeRanges", _t => {
  test("empty array returns empty", t => {
    let result = FileTracker.mergeRanges([])
    t->expect(result)->Expect.toEqual([])
  })

  test("single range returns as-is", t => {
    let result = FileTracker.mergeRanges([{start: 0, end_: 100}])
    t->expect(result)->Expect.toEqual([{start: 0, end_: 100}])
  })

  test("non-overlapping ranges stay separate", t => {
    let result = FileTracker.mergeRanges([{start: 0, end_: 50}, {start: 100, end_: 150}])
    t->expect(result)->Expect.toEqual([{start: 0, end_: 50}, {start: 100, end_: 150}])
  })

  test("overlapping ranges are merged", t => {
    let result = FileTracker.mergeRanges([{start: 0, end_: 100}, {start: 50, end_: 150}])
    t->expect(result)->Expect.toEqual([{start: 0, end_: 150}])
  })

  test("adjacent ranges are merged", t => {
    let result = FileTracker.mergeRanges([{start: 0, end_: 50}, {start: 50, end_: 100}])
    t->expect(result)->Expect.toEqual([{start: 0, end_: 100}])
  })

  test("unsorted ranges are sorted then merged", t => {
    let result = FileTracker.mergeRanges([{start: 100, end_: 200}, {start: 0, end_: 50}])
    t->expect(result)->Expect.toEqual([{start: 0, end_: 50}, {start: 100, end_: 200}])
  })

  test("three ranges with partial overlap", t => {
    let result = FileTracker.mergeRanges([
      {start: 0, end_: 50},
      {start: 40, end_: 100},
      {start: 200, end_: 300},
    ])
    t->expect(result)->Expect.toEqual([{start: 0, end_: 100}, {start: 200, end_: 300}])
  })
})

// ============================================
// recordRead + assertReadBefore
// ============================================

describe("recordRead and assertReadBefore", _t => {
  test("unread file fails assertReadBefore", t => {
    let result = FileTracker.assertReadBefore("/path/to/file.ts")
    t->expect(Result.isError(result))->Expect.toBe(true)
  })

  test("read file passes assertReadBefore", t => {
    FileTracker.recordRead("/path/to/file.ts", ~offset=0, ~limit=500, ~totalLines=100)
    let result = FileTracker.assertReadBefore("/path/to/file.ts")
    t->expect(Result.isOk(result))->Expect.toBe(true)
  })

  test("different file still fails assertReadBefore", t => {
    FileTracker.recordRead("/path/to/a.ts", ~offset=0, ~limit=500, ~totalLines=100)
    let result = FileTracker.assertReadBefore("/path/to/b.ts")
    t->expect(Result.isError(result))->Expect.toBe(true)
  })
})

// ============================================
// recordRead range tracking
// ============================================

describe("recordRead range tracking", _t => {
  test("records initial range", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=500, ~totalLines=1000)
    let record = FileTracker.get("/file.ts")->Option.getOrThrow
    t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 500}])
    t->expect(record.totalLines)->Expect.toBe(1000)
  })

  test("clamps range end to totalLines", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=500, ~totalLines=200)
    let record = FileTracker.get("/file.ts")->Option.getOrThrow
    t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 200}])
  })

  test("merges overlapping reads", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=500, ~totalLines=1000)
    FileTracker.recordRead("/file.ts", ~offset=400, ~limit=500, ~totalLines=1000)
    let record = FileTracker.get("/file.ts")->Option.getOrThrow
    t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 900}])
  })

  test("keeps non-overlapping reads separate", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=100, ~totalLines=1000)
    FileTracker.recordRead("/file.ts", ~offset=500, ~limit=100, ~totalLines=1000)
    let record = FileTracker.get("/file.ts")->Option.getOrThrow
    t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 100}, {start: 500, end_: 600}])
  })

  test("updates readAt on subsequent reads", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=100, ~totalLines=1000)
    let record1 = FileTracker.get("/file.ts")->Option.getOrThrow
    let firstReadAt = record1.readAt

    // Small delay to ensure different timestamp
    FileTracker.recordRead("/file.ts", ~offset=100, ~limit=100, ~totalLines=1000)
    let record2 = FileTracker.get("/file.ts")->Option.getOrThrow
    // readAt should be >= first read (could be equal if very fast)
    t->expect(record2.readAt >= firstReadAt)->Expect.toBe(true)
  })
})

// ============================================
// isLineCovered
// ============================================

describe("isLineCovered", _t => {
  test("line inside range is covered", t => {
    let ranges = [{FileTracker.start: 0, end_: 100}]
    t->expect(FileTracker.isLineCovered(ranges, 50))->Expect.toBe(true)
  })

  test("line at range start is covered", t => {
    let ranges = [{FileTracker.start: 0, end_: 100}]
    t->expect(FileTracker.isLineCovered(ranges, 0))->Expect.toBe(true)
  })

  test("line at range end is NOT covered (exclusive)", t => {
    let ranges = [{FileTracker.start: 0, end_: 100}]
    t->expect(FileTracker.isLineCovered(ranges, 100))->Expect.toBe(false)
  })

  test("line outside all ranges is not covered", t => {
    let ranges = [{FileTracker.start: 0, end_: 50}, {FileTracker.start: 100, end_: 150}]
    t->expect(FileTracker.isLineCovered(ranges, 75))->Expect.toBe(false)
  })

  test("line in second range is covered", t => {
    let ranges = [{FileTracker.start: 0, end_: 50}, {FileTracker.start: 100, end_: 150}]
    t->expect(FileTracker.isLineCovered(ranges, 125))->Expect.toBe(true)
  })
})

// ============================================
// checkCoverage
// ============================================

describe("checkCoverage", _t => {
  test("returns None for untracked file", t => {
    let result = FileTracker.checkCoverage("/unknown.ts", ~content="hello", ~oldText="hello")
    t->expect(result)->Expect.toEqual(None)
  })

  test("returns None when full file was read", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=500, ~totalLines=100)
    let content = Array.make(~length=100, "line")->Array.join("\n")
    let result = FileTracker.checkCoverage("/file.ts", ~content, ~oldText="line")
    t->expect(result)->Expect.toEqual(None)
  })

  test("returns None when edit target is within read range", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=100, ~totalLines=500)
    let lines = Array.make(~length=500, "other")->Array.mapWithIndex((line, idx) =>
      switch idx {
      | 50 => "target line"
      | _ => line
      }
    )
    let content = lines->Array.join("\n")
    let result = FileTracker.checkCoverage("/file.ts", ~content, ~oldText="target line")
    t->expect(result)->Expect.toEqual(None)
  })

  test("returns warning when edit target is outside read range", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=100, ~totalLines=500)
    let lines = Array.make(~length=500, "other")->Array.mapWithIndex((line, idx) =>
      switch idx {
      | 300 => "target line"
      | _ => line
      }
    )
    let content = lines->Array.join("\n")
    let result = FileTracker.checkCoverage("/file.ts", ~content, ~oldText="target line")
    t->expect(Option.isSome(result))->Expect.toBe(true)
    let warning = result->Option.getOrThrow
    t->expect(warning->String.includes("line 300"))->Expect.toBe(true)
    t->expect(warning->String.includes("0-100"))->Expect.toBe(true)
  })

  test("returns None when target line cannot be found", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=100, ~totalLines=500)
    let content = Array.make(~length=500, "other")->Array.join("\n")
    let result = FileTracker.checkCoverage("/file.ts", ~content, ~oldText="nonexistent text")
    t->expect(result)->Expect.toEqual(None)
  })
})

// ============================================
// clear
// ============================================

describe("clear", _t => {
  test("clears all tracked reads", t => {
    FileTracker.recordRead("/a.ts", ~offset=0, ~limit=100, ~totalLines=100)
    FileTracker.recordRead("/b.ts", ~offset=0, ~limit=100, ~totalLines=100)
    FileTracker.clear()
    t->expect(Result.isError(FileTracker.assertReadBefore("/a.ts")))->Expect.toBe(true)
    t->expect(Result.isError(FileTracker.assertReadBefore("/b.ts")))->Expect.toBe(true)
  })
})

// ============================================
// recordWrite
// ============================================

describe("recordWrite", _t => {
  test("updates readAt for tracked file", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=500, ~totalLines=100)
    let record1 = FileTracker.get("/file.ts")->Option.getOrThrow
    let readAtBefore = record1.readAt

    FileTracker.recordWrite("/file.ts")
    let record2 = FileTracker.get("/file.ts")->Option.getOrThrow
    // readAt should be updated to at least the previous value
    t->expect(record2.readAt >= readAtBefore)->Expect.toBe(true)
  })

  test("preserves ranges after write", t => {
    FileTracker.recordRead("/file.ts", ~offset=0, ~limit=100, ~totalLines=500)
    FileTracker.recordWrite("/file.ts")
    let record = FileTracker.get("/file.ts")->Option.getOrThrow
    t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 100}])
  })

  test("no-op for untracked file", t => {
    // Should not crash or create a record
    FileTracker.recordWrite("/untracked.ts")
    t->expect(FileTracker.get("/untracked.ts"))->Expect.toEqual(None)
  })
})
