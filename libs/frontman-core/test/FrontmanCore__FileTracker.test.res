open Vitest

module FileTracker = FrontmanCore__FileTracker
module Fs = FrontmanBindings.Fs
module SafePath = FrontmanCore__SafePath

let _safePath = (path: string): SafePath.t =>
  SafePath.resolve(~sourceRoot="/", ~inputPath=path)->Result.getOrThrow

let _makeTempFile = async (content: string): string => {
  let dir = FrontmanBindings.Os.tmpdir()
  let path =
    dir ++
    "/filetracker_test_" ++
    Float.toString(Date.now()) ++
    "_" ++
    Float.toString(Math.random()) ++ ".txt"
  await Fs.Promises.writeFile(path, content)
  path
}

let _statFile = async (path: string) => {
  let stats = await Fs.Promises.stat(path)
  (Fs.mtimeMs(stats), Fs.size(stats))
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

beforeEach(() => {
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
    let result = FileTracker.assertReadBefore(_safePath("/path/to/file.ts"))
    t->expect(Result.isError(result))->Expect.toBe(true)
  })

  testAsync("read file passes assertReadBefore", async t => {
    await _withTempFile(
      "content",
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=500,
          ~totalLines=1,
          ~mtimeMs,
          ~size,
        )
        let result = FileTracker.assertReadBefore(_safePath(path))
        t->expect(Result.isOk(result))->Expect.toBe(true)
      },
    )
  })

  testAsync("different file still fails assertReadBefore", async t => {
    await _withTempFile(
      "content",
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=500,
          ~totalLines=1,
          ~mtimeMs,
          ~size,
        )
        let result = FileTracker.assertReadBefore(_safePath("/path/to/other.ts"))
        t->expect(Result.isError(result))->Expect.toBe(true)
      },
    )
  })
})

describe("recordRead stores file stat", _t => {
  testAsync("stores mtimeMs from caller-provided stat", async t => {
    await _withTempFile(
      "hello\nworld\n",
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=2,
          ~mtimeMs,
          ~size,
        )
        let record = FileTracker.get(_safePath(path))->Option.getOrThrow
        t->expect(record.mtimeMs)->Expect.toBe(mtimeMs)
      },
    )
  })

  testAsync("stores size from caller-provided stat", async t => {
    await _withTempFile(
      "hello\nworld\n",
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=2,
          ~mtimeMs,
          ~size,
        )
        let record = FileTracker.get(_safePath(path))->Option.getOrThrow
        t->expect(record.size)->Expect.toBe(size)
      },
    )
  })

  testAsync("updates mtimeMs on subsequent reads after file change", async t => {
    await _withTempFile(
      "line1\nline2\n",
      async path => {
        let (mtimeMs1, size1) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=1,
          ~totalLines=2,
          ~mtimeMs=mtimeMs1,
          ~size=size1,
        )
        let mtime1 = (FileTracker.get(_safePath(path))->Option.getOrThrow).mtimeMs

        await Fs.Promises.writeFile(path, "line1\nline2\nline3\n")
        let (mtimeMs2, size2) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=3,
          ~totalLines=3,
          ~mtimeMs=mtimeMs2,
          ~size=size2,
        )
        let mtime2 = (FileTracker.get(_safePath(path))->Option.getOrThrow).mtimeMs
        t->expect(mtime2 >= mtime1)->Expect.toBe(true)
      },
    )
  })
})

describe("recordRead range tracking", _t => {
  testAsync("records initial range", async t => {
    await _withTempFile(
      _lines(1000),
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=500,
          ~totalLines=1000,
          ~mtimeMs,
          ~size,
        )
        let record = FileTracker.get(_safePath(path))->Option.getOrThrow
        t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 500}])
        t->expect(record.totalLines)->Expect.toBe(1000)
      },
    )
  })

  testAsync("clamps range end to totalLines", async t => {
    await _withTempFile(
      _lines(200),
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=500,
          ~totalLines=200,
          ~mtimeMs,
          ~size,
        )
        let record = FileTracker.get(_safePath(path))->Option.getOrThrow
        t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 200}])
      },
    )
  })

  testAsync("merges overlapping reads", async t => {
    await _withTempFile(
      _lines(1000),
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=500,
          ~totalLines=1000,
          ~mtimeMs,
          ~size,
        )
        FileTracker.recordRead(
          _safePath(path),
          ~offset=400,
          ~limit=500,
          ~totalLines=1000,
          ~mtimeMs,
          ~size,
        )
        let record = FileTracker.get(_safePath(path))->Option.getOrThrow
        t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 900}])
      },
    )
  })

  testAsync("keeps non-overlapping reads separate", async t => {
    await _withTempFile(
      _lines(1000),
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=1000,
          ~mtimeMs,
          ~size,
        )
        FileTracker.recordRead(
          _safePath(path),
          ~offset=500,
          ~limit=100,
          ~totalLines=1000,
          ~mtimeMs,
          ~size,
        )
        let record = FileTracker.get(_safePath(path))->Option.getOrThrow
        t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 100}, {start: 500, end_: 600}])
      },
    )
  })

  testAsync("updates readAt on subsequent reads", async t => {
    await _withTempFile(
      _lines(1000),
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=1000,
          ~mtimeMs,
          ~size,
        )
        let firstReadAt = (FileTracker.get(_safePath(path))->Option.getOrThrow).readAt

        FileTracker.recordRead(
          _safePath(path),
          ~offset=100,
          ~limit=100,
          ~totalLines=1000,
          ~mtimeMs,
          ~size,
        )
        let secondReadAt = (FileTracker.get(_safePath(path))->Option.getOrThrow).readAt
        t->expect(secondReadAt >= firstReadAt)->Expect.toBe(true)
      },
    )
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
    let result = FileTracker.checkCoverage(
      _safePath("/unknown.ts"),
      ~content="hello",
      ~oldText="hello",
    )
    t->expect(result)->Expect.toEqual(None)
  })

  testAsync("returns None when full file was read", async t => {
    let content = _lines(100)
    await _withTempFile(
      content,
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=500,
          ~totalLines=100,
          ~mtimeMs,
          ~size,
        )
        let result = FileTracker.checkCoverage(_safePath(path), ~content, ~oldText="line")
        t->expect(result)->Expect.toEqual(None)
      },
    )
  })

  testAsync("returns None when edit target is within read range", async t => {
    let content = _contentWithTargetAt(500, 50, "target line")
    await _withTempFile(
      content,
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=500,
          ~mtimeMs,
          ~size,
        )
        let result = FileTracker.checkCoverage(_safePath(path), ~content, ~oldText="target line")
        t->expect(result)->Expect.toEqual(None)
      },
    )
  })

  testAsync("returns warning when edit target is outside read range", async t => {
    let content = _contentWithTargetAt(500, 300, "target line")
    await _withTempFile(
      content,
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=500,
          ~mtimeMs,
          ~size,
        )
        let result = FileTracker.checkCoverage(_safePath(path), ~content, ~oldText="target line")
        t->expect(Option.isSome(result))->Expect.toBe(true)
        let warning = result->Option.getOrThrow
        t->expect(warning->String.includes("line 300"))->Expect.toBe(true)
        t->expect(warning->String.includes("0-100"))->Expect.toBe(true)
      },
    )
  })

  testAsync("returns None when target line cannot be found", async t => {
    let content = _lines(500)
    await _withTempFile(
      content,
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=500,
          ~mtimeMs,
          ~size,
        )
        let result = FileTracker.checkCoverage(
          _safePath(path),
          ~content,
          ~oldText="nonexistent text",
        )
        t->expect(result)->Expect.toEqual(None)
      },
    )
  })
})

describe("assertNotStale checks mtime and size", _t => {
  testAsync("passes when file unchanged", async t => {
    await _withTempFile(
      "unchanged content",
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=1,
          ~mtimeMs,
          ~size,
        )
        let result = await FileTracker.assertNotStale(_safePath(path))
        t->expect(Result.isOk(result))->Expect.toBe(true)
      },
    )
  })

  testAsync("fails when file modified on disk", async t => {
    await _withTempFile(
      "original",
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=1,
          ~mtimeMs,
          ~size,
        )
        await Fs.Promises.writeFile(path, "modified content that is different")
        let result = await FileTracker.assertNotStale(_safePath(path))
        t->expect(Result.isError(result))->Expect.toBe(true)
      },
    )
  })

  testAsync("fails when file deleted from disk", async t => {
    let path = await _makeTempFile("will be deleted")
    let (mtimeMs, size) = await _statFile(path)
    FileTracker.recordRead(_safePath(path), ~offset=0, ~limit=100, ~totalLines=1, ~mtimeMs, ~size)
    await _removeTempFile(path)
    let result = await FileTracker.assertNotStale(_safePath(path))
    t->expect(Result.isError(result))->Expect.toBe(true)
    switch result {
    | Error(msg) => t->expect(msg->String.includes("no longer accessible"))->Expect.toBe(true)
    | Ok() => t->expect(false)->Expect.toBe(true)
    }
  })
})

describe("clear", _t => {
  testAsync("clears all tracked reads", async t => {
    let pathA = await _makeTempFile("a")
    let pathB = await _makeTempFile("b")
    let (mtimeA, sizeA) = await _statFile(pathA)
    let (mtimeB, sizeB) = await _statFile(pathB)
    FileTracker.recordRead(
      _safePath(pathA),
      ~offset=0,
      ~limit=100,
      ~totalLines=1,
      ~mtimeMs=mtimeA,
      ~size=sizeA,
    )
    FileTracker.recordRead(
      _safePath(pathB),
      ~offset=0,
      ~limit=100,
      ~totalLines=1,
      ~mtimeMs=mtimeB,
      ~size=sizeB,
    )
    FileTracker.clear()
    t->expect(Result.isError(FileTracker.assertReadBefore(_safePath(pathA))))->Expect.toBe(true)
    t->expect(Result.isError(FileTracker.assertReadBefore(_safePath(pathB))))->Expect.toBe(true)
    await _removeTempFile(pathA)
    await _removeTempFile(pathB)
  })
})

describe("recordWrite", _t => {
  testAsync("updates readAt for tracked file", async t => {
    await _withTempFile(
      "content",
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=500,
          ~totalLines=1,
          ~mtimeMs,
          ~size,
        )
        let readAtBefore = (FileTracker.get(_safePath(path))->Option.getOrThrow).readAt

        FileTracker.recordWrite(_safePath(path), ~mtimeMs, ~size)
        let readAtAfter = (FileTracker.get(_safePath(path))->Option.getOrThrow).readAt
        t->expect(readAtAfter >= readAtBefore)->Expect.toBe(true)
      },
    )
  })

  testAsync("preserves ranges after write", async t => {
    let content = _lines(500)
    await _withTempFile(
      content,
      async path => {
        let (mtimeMs, size) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=500,
          ~mtimeMs,
          ~size,
        )
        FileTracker.recordWrite(_safePath(path), ~mtimeMs, ~size)
        let record = FileTracker.get(_safePath(path))->Option.getOrThrow
        t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 100}])
      },
    )
  })

  test("no-op for untracked file", t => {
    FileTracker.recordWrite(_safePath("/untracked.ts"), ~mtimeMs=0.0, ~size=0.0)
    t->expect(FileTracker.get(_safePath("/untracked.ts")))->Expect.toEqual(None)
  })
})

describe("recordWrite re-stats file", _t => {
  testAsync("updates mtimeMs after write", async t => {
    await _withTempFile(
      "original",
      async path => {
        let (mtimeMs1, size1) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=1,
          ~mtimeMs=mtimeMs1,
          ~size=size1,
        )
        let mtimeBefore = (FileTracker.get(_safePath(path))->Option.getOrThrow).mtimeMs

        await Fs.Promises.writeFile(path, "updated content")
        let (mtimeMs2, size2) = await _statFile(path)
        FileTracker.recordWrite(_safePath(path), ~mtimeMs=mtimeMs2, ~size=size2)

        let mtimeAfter = (FileTracker.get(_safePath(path))->Option.getOrThrow).mtimeMs
        t->expect(mtimeAfter >= mtimeBefore)->Expect.toBe(true)
      },
    )
  })

  testAsync("updates size after write", async t => {
    await _withTempFile(
      "short",
      async path => {
        let (mtimeMs1, size1) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=1,
          ~mtimeMs=mtimeMs1,
          ~size=size1,
        )
        let sizeBefore = (FileTracker.get(_safePath(path))->Option.getOrThrow).size

        await Fs.Promises.writeFile(path, "this is much longer content than before")
        let (mtimeMs2, size2) = await _statFile(path)
        FileTracker.recordWrite(_safePath(path), ~mtimeMs=mtimeMs2, ~size=size2)

        let sizeAfter = (FileTracker.get(_safePath(path))->Option.getOrThrow).size
        t->expect(sizeAfter > sizeBefore)->Expect.toBe(true)
      },
    )
  })

  testAsync("subsequent assertNotStale passes after recordWrite", async t => {
    await _withTempFile(
      "v1",
      async path => {
        let (mtimeMs1, size1) = await _statFile(path)
        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=1,
          ~mtimeMs=mtimeMs1,
          ~size=size1,
        )

        await Fs.Promises.writeFile(path, "v2")
        let (mtimeMs2, size2) = await _statFile(path)
        FileTracker.recordWrite(_safePath(path), ~mtimeMs=mtimeMs2, ~size=size2)

        let result = await FileTracker.assertNotStale(_safePath(path))
        t->expect(Result.isOk(result))->Expect.toBe(true)
      },
    )
  })
})

describe("TOCTOU regression", _t => {
  testAsync("stale stats from before file modification are detected by assertNotStale", async t => {
    await _withTempFile(
      "original content",
      async path => {
        let (mtimeMs, size) = await _statFile(path)

        await Fs.Promises.writeFile(path, "externally modified content that differs")

        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=1,
          ~mtimeMs,
          ~size,
        )

        let result = await FileTracker.assertNotStale(_safePath(path))
        t->expect(Result.isError(result))->Expect.toBe(true)
      },
    )
  })
})

describe("concurrent recordRead range preservation", _t => {
  testAsync("synchronous recordRead calls preserve all ranges", async t => {
    await _withTempFile(
      _lines(1000),
      async path => {
        let (mtimeMs, size) = await _statFile(path)

        FileTracker.recordRead(
          _safePath(path),
          ~offset=0,
          ~limit=100,
          ~totalLines=1000,
          ~mtimeMs,
          ~size,
        )
        FileTracker.recordRead(
          _safePath(path),
          ~offset=500,
          ~limit=100,
          ~totalLines=1000,
          ~mtimeMs,
          ~size,
        )

        let record = FileTracker.get(_safePath(path))->Option.getOrThrow
        t->expect(record.ranges)->Expect.toEqual([{start: 0, end_: 100}, {start: 500, end_: 600}])
      },
    )
  })
})
