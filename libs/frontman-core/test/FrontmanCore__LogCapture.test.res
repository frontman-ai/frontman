open Vitest

module LogCapture = FrontmanCore__LogCapture

let _testEpipeOnStream: (LogCapture.state => unit, LogCapture.state, string) => bool = %raw(`
  function(interceptFn, state, streamName) {
    var stream = process[streamName];
    var savedWrite = stream.write;
    stream.write = function() {
      var err = new Error('write EPIPE');
      err.code = 'EPIPE';
      throw err;
    };
    try {
      interceptFn(state);
      stream.write("test epipe\\n");
      return true;
    } catch(e) {
      return false;
    } finally {
      stream.write = savedWrite;
    }
  }
`)

let _testNonEpipeOnStream: (LogCapture.state => unit, LogCapture.state, string) => bool = %raw(`
  function(interceptFn, state, streamName) {
    var stream = process[streamName];
    var savedWrite = stream.write;
    stream.write = function() {
      throw new TypeError('some other error');
    };
    try {
      interceptFn(state);
      stream.write("test\\n");
      return false;
    } catch(e) {
      return e instanceof TypeError;
    } finally {
      stream.write = savedWrite;
    }
  }
`)

describe("LogCapture", _t => {
  describe("interceptStdout EPIPE guard", _t => {
    test(
      "stdout write survives EPIPE error without crashing",
      t => {
        let state = LogCapture.getOrCreateInstance(~config=LogCapture.defaultConfig)
        t
        ->expect(_testEpipeOnStream(LogCapture.interceptStdout, state, "stdout"))
        ->Expect.toBe(true)
      },
    )

    test(
      "stderr write survives EPIPE error without crashing",
      t => {
        let state = LogCapture.getOrCreateInstance(~config=LogCapture.defaultConfig)
        t
        ->expect(_testEpipeOnStream(LogCapture.interceptStdout, state, "stderr"))
        ->Expect.toBe(true)
      },
    )

    test(
      "non-EPIPE errors still propagate",
      t => {
        let state = LogCapture.getOrCreateInstance(~config=LogCapture.defaultConfig)
        t
        ->expect(_testNonEpipeOnStream(LogCapture.interceptStdout, state, "stdout"))
        ->Expect.toBe(true)
      },
    )
  })

  describe("Build-level tagging via console", _t => {
    beforeAll(
      _t => {
        let state = LogCapture.getOrCreateInstance(~config=LogCapture.defaultConfig)
        LogCapture.interceptConsole(state)
        LogCapture.interceptStdout(state)
      },
    )

    test(
      "console.log matching pattern is tagged as Build level",
      t => {
        Console.log("webpack compiled successfully zzzcore")

        let logs = LogCapture.getLogs(~level=Build)
        let found =
          logs->Array.some(
            log => log.message->String.includes("webpack compiled successfully zzzcore"),
          )

        t->expect(found)->Expect.toBe(true)
      },
    )

    test(
      "console.log not matching pattern stays as Console level",
      t => {
        Console.log("ordinary chat message zzzcore2")

        let consoleLogs = LogCapture.getLogs(~level=Console)
        let found =
          consoleLogs->Array.some(
            log => log.message->String.includes("ordinary chat message zzzcore2"),
          )

        t->expect(found)->Expect.toBe(true)
      },
    )

    test(
      "console.log matching build pattern does not produce duplicate entries",
      t => {
        let marker = "turbopack compiled zzz-dedup-test"
        Console.log(marker)

        let buildLogs = LogCapture.getLogs(~level=Build)
        let matches = buildLogs->Array.filter(log => log.message->String.includes(marker))

        t->expect(matches->Array.length)->Expect.toBe(1)
      },
    )
  })
})
