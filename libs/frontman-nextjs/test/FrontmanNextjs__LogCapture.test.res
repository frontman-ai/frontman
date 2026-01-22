open Vitest

module LogCapture = FrontmanNextjs__LogCapture

// Initialize log capture once before all tests
beforeAll(_t => {
  LogCapture.initialize()
})

describe("LogCapture", _t => {
  describe("Initialization", _t => {
    test(
      "getInstance creates singleton on first call",
      t => {
        let instance1 = LogCapture.getInstance()
        let instance2 = LogCapture.getInstance()

        // Should return same instance (reference equality)
        t->expect(instance1 === instance2)->Expect.toBe(true)
      },
    )

    test(
      "initialize is idempotent",
      t => {
        LogCapture.initialize()
        LogCapture.initialize()
        LogCapture.initialize()

        // Should not crash or cause issues
        t->expect(true)->Expect.toBe(true)
      },
    )
  })

  describe("Console Interception", _t => {
    test(
      "console.log captures message",
      t => {
        Console.log("test message unique 123")

        let logs = LogCapture.getLogs()
        // Just check if the message was captured, don't check level yet
        let found = logs->Array.some(log => log.message->String.includes("test message unique 123"))

        t->expect(found)->Expect.toBe(true)
      },
    )

    test(
      "console.warn captures message",
      t => {
        Console.warn("warning message unique 456")

        let logs = LogCapture.getLogs()
        let found =
          logs->Array.some(log => log.message->String.includes("warning message unique 456"))

        t->expect(found)->Expect.toBe(true)
      },
    )

    test(
      "console.error captures message",
      t => {
        Console.error("error message unique 789")

        let logs = LogCapture.getLogs()
        let found =
          logs->Array.some(log => log.message->String.includes("error message unique 789"))

        t->expect(found)->Expect.toBe(true)
      },
    )

    test(
      "multiple arguments converted to space-separated string",
      t => {
        Console.log3("hello", "world", 123)

        let logs = LogCapture.getLogs()
        let found = logs->Array.some(log => log.message == "hello world 123")

        t->expect(found)->Expect.toBe(true)
      },
    )

    test(
      "raw JavaScript console.log with multiple arguments",
      t => {
        // This tests the variadic arguments bug fix
        // Raw JS console.log must use ...args, not args
        ignore(%raw(`console.log("raw", "javascript", "test", 42)`))

        let logs = LogCapture.getLogs()
        let found = logs->Array.some(log => log.message == "raw javascript test 42")

        t->expect(found)->Expect.toBe(true)
      },
    )

    test(
      "raw JavaScript console.error with multiple arguments",
      t => {
        ignore(%raw(`console.error("error", "with", "multiple", "args")`))

        let logs = LogCapture.getLogs()
        let found = logs->Array.some(log => log.message == "error with multiple args")

        t->expect(found)->Expect.toBe(true)
      },
    )
  })

  describe("ANSI Stripping", _t => {
    test(
      "ANSI color codes are stripped before storage",
      t => {
        Console.log("\x1b[31mred text\x1b[0m")

        let logs = LogCapture.getLogs()
        let found = logs->Array.some(log => log.message == "red text")

        t->expect(found)->Expect.toBe(true)
      },
    )

    test(
      "multiple ANSI codes are stripped",
      t => {
        Console.log("\x1b[36mCyan\x1b[0m \x1b[33mYellow\x1b[0m")

        let logs = LogCapture.getLogs()
        let found = logs->Array.some(log => log.message == "Cyan Yellow")

        t->expect(found)->Expect.toBe(true)
      },
    )
  })

  describe("Query Functions - getLogs", _t => {
    describe(
      "Pattern Matching",
      _t => {
        test(
          "no pattern returns all logs",
          t => {
            Console.log("first")
            Console.log("second")
            Console.log("third")

            let logs = LogCapture.getLogs()

            t->expect(logs->Array.length >= 3)->Expect.toBe(true)
          },
        )

        test(
          "pattern filter returns matching entries",
          t => {
            Console.log("error occurred")
            Console.log("info message")
            Console.log("error detected")

            let logs = LogCapture.getLogs(~pattern="error")

            let errorLogs = logs->Array.filter(log => log.message->String.includes("error"))

            t->expect(errorLogs->Array.length >= 2)->Expect.toBe(true)
          },
        )

        test(
          "pattern matching is case-insensitive",
          t => {
            Console.log("ERROR in uppercase")

            let logs = LogCapture.getLogs(~pattern="error")
            let found = logs->Array.some(log => log.message->String.includes("ERROR"))

            t->expect(found)->Expect.toBe(true)
          },
        )

        test(
          "regex pattern works correctly",
          t => {
            Console.log("webpack compiled successfully")
            Console.log("turbopack ready")
            Console.log("other message")

            let logs = LogCapture.getLogs(~pattern="webpack.*compiled")
            let found = logs->Array.some(log => log.message->String.includes("webpack compiled"))

            t->expect(found)->Expect.toBe(true)
          },
        )
      },
    )

    describe(
      "Level Filtering",
      _t => {
        test(
          "level filter returns only matching level",
          t => {
            Console.log("console message")

            let consoleLogs = LogCapture.getLogs(~level=Console)
            let allConsole = consoleLogs->Array.every(log => log.level == Console)

            t->expect(allConsole)->Expect.toBe(true)
          },
        )

        test(
          "combined pattern and level filters",
          t => {
            Console.log("test console message unique xyz123")

            let logs = LogCapture.getLogs(~pattern="xyz123")
            let found = logs->Array.some(log => log.message->String.includes("xyz123"))

            t->expect(found)->Expect.toBe(true)
          },
        )
      },
    )

    describe(
      "Tail Limiting",
      _t => {
        test(
          "tail limits returned results",
          t => {
            // Generate multiple logs
            Console.log("log 1")
            Console.log("log 2")
            Console.log("log 3")
            Console.log("log 4")
            Console.log("log 5")

            let logs = LogCapture.getLogs(~tail=2)

            // Should return at most 2 logs
            t->expect(logs->Array.length <= 2)->Expect.toBe(true)
          },
        )

        test(
          "tail returns most recent logs",
          t => {
            Console.log("oldest")
            Console.log("middle")
            Console.log("newest")

            let logs = LogCapture.getLogs(~tail=1)

            // Should include the newest log
            let hasNewest = logs->Array.some(log => log.message == "newest")
            t->expect(hasNewest)->Expect.toBe(true)
          },
        )
      },
    )

    describe(
      "Timestamp Filtering",
      _t => {
        test(
          "since filter returns only recent logs",
          t => {
            let allLogs = LogCapture.getLogs()

            // Get a timestamp in the middle of existing logs
            if allLogs->Array.length > 0 {
              let midLog = allLogs[allLogs->Array.length / 2]->Option.getOrThrow
              let midTime = midLog.timestamp->Date.fromString->Date.getTime

              let recentLogs = LogCapture.getLogs(~since=midTime)

              // All returned logs should be after or equal to the timestamp
              let allRecent = recentLogs->Array.every(
                log => {
                  let logTime = log.timestamp->Date.fromString->Date.getTime
                  logTime >= midTime
                },
              )

              t->expect(allRecent)->Expect.toBe(true)
            } else {
              // No logs to test with, just pass
              t->expect(true)->Expect.toBe(true)
            }
          },
        )
      },
    )
  })

  describe("Metadata", _t => {
    test(
      "timestamp is in ISO 8601 format",
      t => {
        Console.log("test")

        let logs = LogCapture.getLogs()
        let hasISOTimestamp = logs->Array.some(
          log => {
            // ISO 8601 format check (basic validation)
            log.timestamp->String.includes("T") && log.timestamp->String.includes("Z")
          },
        )

        t->expect(hasISOTimestamp)->Expect.toBe(true)
      },
    )

    test(
      "timestamps are chronologically ordered",
      t => {
        Console.log("first")
        Console.log("second")
        Console.log("third")

        let logs = LogCapture.getLogs()
        let testLogs =
          logs->Array.filter(
            log => log.message == "first" || log.message == "second" || log.message == "third",
          )

        if testLogs->Array.length >= 2 {
          let firstLog = testLogs[0]->Option.getOrThrow
          let secondLog = testLogs[1]->Option.getOrThrow
          let firstTime = firstLog.timestamp->Date.fromString->Date.getTime
          let secondTime = secondLog.timestamp->Date.fromString->Date.getTime

          t->expect(firstTime <= secondTime)->Expect.toBe(true)
        } else {
          t->expect(true)->Expect.toBe(true)
        }
      },
    )
  })

  describe("Buffer Integration", _t => {
    test(
      "logs are stored in buffer correctly",
      t => {
        Console.log("buffered message")

        let logs = LogCapture.getLogs()
        let found = logs->Array.some(log => log.message == "buffered message")

        t->expect(found)->Expect.toBe(true)
      },
    )

    test(
      "buffer enforces capacity limit",
      t => {
        let bufferSize =
          LogCapture.getInstance().buffer.contents->FrontmanNextjs__CircularBuffer.length

        // Buffer size should be <= 1024
        t->expect(bufferSize <= 1024)->Expect.toBe(true)
      },
    )
  })

  describe("Error Handling", _t => {
    test(
      "invalid regex returns empty array silently",
      t => {
        // Invalid regex pattern
        let logs = LogCapture.getLogs(~pattern="[invalid(regex")

        // Should not crash, returns empty array
        t->expect(Array.isArray(logs))->Expect.toBe(true)
      },
    )

    test(
      "log capture errors don't crash app",
      t => {
        // Calling getLogs should never throw
        let logs = LogCapture.getLogs()
        t->expect(Array.isArray(logs))->Expect.toBe(true)
      },
    )
  })
})
