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
    t->expect(ToolCallBlock.cleanToolName("navigate"))->Expect.toBe("navigate")
  })
})

describe("isInlineTool", _t => {
  test("returns true for file tools", t => {
    t->expect(ToolCallBlock.isInlineTool("read_file"))->Expect.toBe(true)
    t->expect(ToolCallBlock.isInlineTool("write_file"))->Expect.toBe(true)
    t->expect(ToolCallBlock.isInlineTool("list_files"))->Expect.toBe(true)
    t->expect(ToolCallBlock.isInlineTool("list_dir"))->Expect.toBe(true)
  })

  test("returns true for navigate", t => {
    t->expect(ToolCallBlock.isInlineTool("navigate"))->Expect.toBe(true)
  })

  test("returns false for other tools", t => {
    t->expect(ToolCallBlock.isInlineTool("take_screenshot"))->Expect.toBe(false)
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

  test("returns false for navigate", t => {
    t->expect(ToolCallBlock.isFileTool("navigate"))->Expect.toBe(false)
  })
})

describe("getNavigateTarget", _t => {
  test("returns URL for goto action", t => {
    let input = Some(JSON.parseOrThrow(`{"action": "goto", "url": "/about"}`))
    t->expect(ToolCallBlock.getNavigateTarget(input))->Expect.toEqual(Some("/about"))
  })

  test("returns action name for back action", t => {
    let input = Some(JSON.parseOrThrow(`{"action": "back"}`))
    t->expect(ToolCallBlock.getNavigateTarget(input))->Expect.toEqual(Some("back"))
  })

  test("returns action name for forward action", t => {
    let input = Some(JSON.parseOrThrow(`{"action": "forward"}`))
    t->expect(ToolCallBlock.getNavigateTarget(input))->Expect.toEqual(Some("forward"))
  })

  test("returns action name for refresh action", t => {
    let input = Some(JSON.parseOrThrow(`{"action": "refresh"}`))
    t->expect(ToolCallBlock.getNavigateTarget(input))->Expect.toEqual(Some("refresh"))
  })

  test("returns None when input is None", t => {
    t->expect(ToolCallBlock.getNavigateTarget(None))->Expect.toEqual(None)
  })

  test("returns None for non-object JSON", t => {
    let input = Some(JSON.parseOrThrow(`"just a string"`))
    t->expect(ToolCallBlock.getNavigateTarget(input))->Expect.toEqual(None)
  })

  test("returns None when action is missing", t => {
    let input = Some(JSON.parseOrThrow(`{"url": "/test"}`))
    t->expect(ToolCallBlock.getNavigateTarget(input))->Expect.toEqual(None)
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

  test("delegates to getNavigateTarget for navigate", t => {
    let input = Some(JSON.parseOrThrow(`{"action": "goto", "url": "/products"}`))
    t->expect(ToolCallBlock.getTarget("navigate", input))->Expect.toEqual(Some("/products"))
  })

  test("returns None for navigate without input", t => {
    t->expect(ToolCallBlock.getTarget("navigate", None))->Expect.toEqual(None)
  })

  test("returns action for navigate back", t => {
    let input = Some(JSON.parseOrThrow(`{"action": "back"}`))
    t->expect(ToolCallBlock.getTarget("navigate", input))->Expect.toEqual(Some("back"))
  })
})
