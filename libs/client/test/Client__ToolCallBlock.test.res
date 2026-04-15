open Vitest

module ToolCallBlock = Client__ToolCallBlock

describe("cleanToolName", _t => {
  test("lowercases without stripping any prefix", t => {
    t->expect(ToolCallBlock.cleanToolName("Calling write_file"))->Expect.toBe("calling write_file")
  })

  test("lowercases without prefix", t => {
    t->expect(ToolCallBlock.cleanToolName("Write_File"))->Expect.toBe("write_file")
  })

  test("handles already clean names", t => {
    t->expect(ToolCallBlock.cleanToolName("execute_js"))->Expect.toBe("execute_js")
  })
})

describe("isInlineTool", _t => {
  test("returns true for file tools", t => {
    t->expect(ToolCallBlock.isInlineTool("read_file"))->Expect.toBe(true)
    t->expect(ToolCallBlock.isInlineTool("write_file"))->Expect.toBe(true)
    t->expect(ToolCallBlock.isInlineTool("list_files"))->Expect.toBe(true)
    t->expect(ToolCallBlock.isInlineTool("list_dir"))->Expect.toBe(true)
  })

  test("returns false for other tools", t => {
    t->expect(ToolCallBlock.isInlineTool("take_screenshot"))->Expect.toBe(false)
    t->expect(ToolCallBlock.isInlineTool("execute_js"))->Expect.toBe(false)
    t->expect(ToolCallBlock.isInlineTool("get_logs"))->Expect.toBe(false)
    t->expect(ToolCallBlock.isInlineTool("consoleLog"))->Expect.toBe(false)
  })
})

describe("isFileTool", _t => {
  test("returns true for file tools only", t => {
    t->expect(ToolCallBlock.isFileTool("read_file"))->Expect.toBe(true)
    t->expect(ToolCallBlock.isFileTool("write_file"))->Expect.toBe(true)
    t->expect(ToolCallBlock.isFileTool("list_files"))->Expect.toBe(true)
    t->expect(ToolCallBlock.isFileTool("list_dir"))->Expect.toBe(true)
  })

  test("returns false for execute_js", t => {
    t->expect(ToolCallBlock.isFileTool("execute_js"))->Expect.toBe(false)
  })
})

describe("getTarget", _t => {
  test("returns file path from tool input", t => {
    let input = Some(JSON.parseOrThrow(`{"target_file": "src/app.tsx"}`))
    t->expect(ToolCallBlock.getTarget("write_file", input))->Expect.toEqual(Some("src/app.tsx"))
  })

  test("normalizes '.' to './' for file tools", t => {
    let input = Some(JSON.parseOrThrow(`{"path": "."}`))
    t->expect(ToolCallBlock.getTarget("list_dir", input))->Expect.toEqual(Some("./"))
  })

  test("defaults to './' when file tool has no input", t => {
    t->expect(ToolCallBlock.getTarget("read_file", None))->Expect.toEqual(Some("./"))
    t->expect(ToolCallBlock.getTarget("list_dir", None))->Expect.toEqual(Some("./"))
  })

  test("returns None for non-inline tools without input", t => {
    t->expect(ToolCallBlock.getTarget("take_screenshot", None))->Expect.toEqual(None)
  })

  test("returns None for execute_js without input", t => {
    t->expect(ToolCallBlock.getTarget("execute_js", None))->Expect.toEqual(None)
  })
})
