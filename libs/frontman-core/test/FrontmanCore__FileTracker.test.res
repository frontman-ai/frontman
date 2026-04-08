open Vitest

module FileTracker = FrontmanCore__FileTracker
module Fs = FrontmanBindings.Fs

let _makeTempFile = async (content: string): string => {
  let dir = FrontmanBindings.Os.tmpdir()
  let path =
    dir ++
    "/filetracker_test_" ++
    Float.toString(Date.now()) ++
    "_" ++
    Float.toString(Math.random()) ++
    ".txt"
  await Fs.Promises.writeFile(path, content)
  path
}

let _removeTempFile = async (path: string): unit => {
  try {
    await Fs.Promises.unlink(path)
  } catch {
  | _ => ()
  }
}

let _withTempFile = async (content: string, fn: string => promise<unit>): unit => {
  let path = await _makeTempFile(content)
  try {
    await fn(path)
    await _removeTempFile(path)
  } catch {
  | exn =>
    await _removeTempFile(path)
    throw(exn)
  }
}

let _contentWithTargetAt = (totalLines, targetIdx, targetText) => {
  Array.make(~length=totalLines, "other")
  ->Array.mapWithIndex((line, idx) =>
    switch idx == targetIdx {
    | true => targetText
    | false => line
    }
  )
  ->Array.join("\n")
}

let _lines = n => Array.make(~length=n, "line")->Array.join("\n")

beforeEach(_t => {
  FileTracker.clear()
})

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

describe("recordRead and assertReadBefore", _t => {
  test("unread file fails assertReadBefore", t => {
    let result = FileTracker.assertReadBefore("/path/to/file.ts")
    t->expect(Result.isError(result))->Expect.toBe(true)
  })

  testAsync("read file passes assertReadBefore", async t => {
    await _withTempFile("content", async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=500, ~totalLines=1)
      let result = FileTracker.assertReadBefore(path)
      t->expect(Result.isOk(result))->Expect.toBe(true)
    })
  })

  testAsync("different file still fails assertReadBefore", async t => {
    await _withTempFile("content", async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=500, ~totalLines=1)
      let result = FileTracker.assertReadBefore("/path/to/other.ts")
      t->expect(Result.isError(result))->Expect.toBe(true)
    })
  })
})

describe("recordRead stores file stat", _t => {
  testAsync("stores mtimeMs from actual file stat", async t => {
    await _withTempFile("hello\nworld\n", async path => {
      let stats = await Fs.Promises.stat(path)
      let expectedMtime = Fs.mtimeMs(stats)

      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=2)
      let record = FileTracker.get(path)->Option.getOrThrow
      t->expect(record.mtimeMs)->Expect.toBe(expectedMtime)
    })
  })

  testAsync("stores size from actual file stat", async t => {
    await _withTempFile("hello\nworld\n", async path => {
      let stats = await Fs.Promises.stat(path)
      let expectedSize = Fs.size(stats)

      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=2)
      let record = FileTracker.get(path)->Option.getOrThrow
      t->expect(record.size)->Expect.toBe(expectedSize)
    })
  })

  testAsync("updates mtimeMs on subsequent reads after file change", async t => {
    await _withTempFile("line1\nline2\n", async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=1, ~totalLines=2)
      let mtime1 = (FileTracker.get(path)->Option.getOrThrow).mtimeMs

      await Fs.Promises.writeFile(path, "line1\nline2\nline3\n")
      await FileTracker.recordRead(path, ~offset=0, ~limit=3, ~totalLines=3)
      let mtime2 = (FileTracker.get(path)->Option.getOrThrow).mtimeMs
      t->expect(mtime2 >= mtime1)->Expect.toBe(true)
    })
  })
})

describe("recordRead range tracking", _t => {
  testAsync("records initial range", async t => {
    await _withTempFile(_lines(1000), async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=500, ~totalLines=1000)
      let record = FileTracker.get(path)->Option.getOrThrow
      t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 500}])
      t->expect(record.totalLines)->Expect.toBe(1000)
    })
  })

  testAsync("clamps range end to totalLines", async t => {
    await _withTempFile(_lines(200), async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=500, ~totalLines=200)
      let record = FileTracker.get(path)->Option.getOrThrow
      t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 200}])
    })
  })

  testAsync("merges overlapping reads", async t => {
    await _withTempFile(_lines(1000), async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=500, ~totalLines=1000)
      await FileTracker.recordRead(path, ~offset=400, ~limit=500, ~totalLines=1000)
      let record = FileTracker.get(path)->Option.getOrThrow
      t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 900}])
    })
  })

  testAsync("keeps non-overlapping reads separate", async t => {
    await _withTempFile(_lines(1000), async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=1000)
      await FileTracker.recordRead(path, ~offset=500, ~limit=100, ~totalLines=1000)
      let record = FileTracker.get(path)->Option.getOrThrow
      t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 100}, {start: 500, end_: 600}])
    })
  })

  testAsync("updates readAt on subsequent reads", async t => {
    await _withTempFile(_lines(1000), async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=1000)
      let firstReadAt = (FileTracker.get(path)->Option.getOrThrow).readAt

      await FileTracker.recordRead(path, ~offset=100, ~limit=100, ~totalLines=1000)
      let secondReadAt = (FileTracker.get(path)->Option.getOrThrow).readAt
      t->expect(secondReadAt >= firstReadAt)->Expect.toBe(true)
    })
  })
})

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

describe("checkCoverage", _t => {
  test("returns None for untracked file", t => {
    let result = FileTracker.checkCoverage("/unknown.ts", ~content="hello", ~oldText="hello")
    t->expect(result)->Expect.toEqual(None)
  })

  testAsync("returns None when full file was read", async t => {
    let content = _lines(100)
    await _withTempFile(content, async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=500, ~totalLines=100)
      let result = FileTracker.checkCoverage(path, ~content, ~oldText="line")
      t->expect(result)->Expect.toEqual(None)
    })
  })

  testAsync("returns None when edit target is within read range", async t => {
    let content = _contentWithTargetAt(500, 50, "target line")
    await _withTempFile(content, async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=500)
      let result = FileTracker.checkCoverage(path, ~content, ~oldText="target line")
      t->expect(result)->Expect.toEqual(None)
    })
  })

  testAsync("returns warning when edit target is outside read range", async t => {
    let content = _contentWithTargetAt(500, 300, "target line")
    await _withTempFile(content, async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=500)
      let result = FileTracker.checkCoverage(path, ~content, ~oldText="target line")
      t->expect(Option.isSome(result))->Expect.toBe(true)
      let warning = result->Option.getOrThrow
      t->expect(warning->String.includes("line 300"))->Expect.toBe(true)
      t->expect(warning->String.includes("0-100"))->Expect.toBe(true)
    })
  })

  testAsync("returns None when target line cannot be found", async t => {
    let content = _lines(500)
    await _withTempFile(content, async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=500)
      let result = FileTracker.checkCoverage(path, ~content, ~oldText="nonexistent text")
      t->expect(result)->Expect.toEqual(None)
    })
  })
})

describe("assertNotStale checks mtime and size", _t => {
  testAsync("passes when file unchanged", async t => {
    await _withTempFile("unchanged content", async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=1)
      let result = await FileTracker.assertNotStale(path)
      t->expect(Result.isOk(result))->Expect.toBe(true)
    })
  })

  testAsync("fails when file modified on disk", async t => {
    await _withTempFile("original", async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=1)
      await Fs.Promises.writeFile(path, "modified content that is different")
      let result = await FileTracker.assertNotStale(path)
      t->expect(Result.isError(result))->Expect.toBe(true)
    })
  })
})

describe("clear", _t => {
  testAsync("clears all tracked reads", async t => {
    let pathA = await _makeTempFile("a")
    let pathB = await _makeTempFile("b")
    await FileTracker.recordRead(pathA, ~offset=0, ~limit=100, ~totalLines=1)
    await FileTracker.recordRead(pathB, ~offset=0, ~limit=100, ~totalLines=1)
    FileTracker.clear()
    t->expect(Result.isError(FileTracker.assertReadBefore(pathA)))->Expect.toBe(true)
    t->expect(Result.isError(FileTracker.assertReadBefore(pathB)))->Expect.toBe(true)
    await _removeTempFile(pathA)
    await _removeTempFile(pathB)
  })
})

describe("recordWrite", _t => {
  testAsync("updates readAt for tracked file", async t => {
    await _withTempFile("content", async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=500, ~totalLines=1)
      let readAtBefore = (FileTracker.get(path)->Option.getOrThrow).readAt

      await FileTracker.recordWrite(path)
      let readAtAfter = (FileTracker.get(path)->Option.getOrThrow).readAt
      t->expect(readAtAfter >= readAtBefore)->Expect.toBe(true)
    })
  })

  testAsync("preserves ranges after write", async t => {
    let content = _lines(500)
    await _withTempFile(content, async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=500)
      await FileTracker.recordWrite(path)
      let record = FileTracker.get(path)->Option.getOrThrow
      t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 100}])
    })
  })

  testAsync("no-op for untracked file", async t => {
    await FileTracker.recordWrite("/untracked.ts")
    t->expect(FileTracker.get("/untracked.ts"))->Expect.toEqual(None)
  })
})

describe("recordWrite re-stats file", _t => {
  testAsync("updates mtimeMs after write", async t => {
    await _withTempFile("original", async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=1)
      let mtimeBefore = (FileTracker.get(path)->Option.getOrThrow).mtimeMs

      await Fs.Promises.writeFile(path, "updated content")
      await FileTracker.recordWrite(path)

      let mtimeAfter = (FileTracker.get(path)->Option.getOrThrow).mtimeMs
      t->expect(mtimeAfter >= mtimeBefore)->Expect.toBe(true)
    })
  })

  testAsync("updates size after write", async t => {
    await _withTempFile("short", async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=1)
      let sizeBefore = (FileTracker.get(path)->Option.getOrThrow).size

      await Fs.Promises.writeFile(path, "this is much longer content than before")
      await FileTracker.recordWrite(path)

      let sizeAfter = (FileTracker.get(path)->Option.getOrThrow).size
      t->expect(sizeAfter > sizeBefore)->Expect.toBe(true)
    })
  })

  testAsync("subsequent assertNotStale passes after recordWrite", async t => {
    await _withTempFile("v1", async path => {
      await FileTracker.recordRead(path, ~offset=0, ~limit=100, ~totalLines=1)

      await Fs.Promises.writeFile(path, "v2")
      await FileTracker.recordWrite(path)

      let result = await FileTracker.assertNotStale(path)
      t->expect(Result.isOk(result))->Expect.toBe(true)
    })
  })
})

describe("withLock", _t => {
  testAsync("serializes concurrent writes to the same path", async t => {
    let order = []

    let task1 = FileTracker.withLock("/same/path.ts", async () => {
      await Promise.make((resolve, _) => {
        let _ = setTimeout(() => resolve(), 50)
      })
      let _ = order->Array.push("task1")
    })

    let task2 = FileTracker.withLock("/same/path.ts", async () => {
      let _ = order->Array.push("task2")
    })

    await task1
    await task2
    t->expect(order)->Expect.toEqual(["task1", "task2"])
  })

  testAsync("allows concurrent writes to different paths", async t => {
    let order = []

    let task1 = FileTracker.withLock("/path/a.ts", async () => {
      await Promise.make((resolve, _) => {
        let _ = setTimeout(() => resolve(), 50)
      })
      let _ = order->Array.push("a")
    })

    let task2 = FileTracker.withLock("/path/b.ts", async () => {
      let _ = order->Array.push("b")
    })

    await task1
    await task2
    t->expect(order)->Expect.toEqual(["b", "a"])
  })

  testAsync("releases lock even if callback throws", async t => {
    try {
      await FileTracker.withLock("/path.ts", async () => {
        JsError.throwWithMessage("boom")
      })
    } catch {
    | _ => ()
    }

    let ran = ref(false)
    await FileTracker.withLock("/path.ts", async () => {
      ran := true
    })
    t->expect(ran.contents)->Expect.toBe(true)
  })
})
