open Vitest

module SmartSerialize = Client__Tool__SmartSerialize

// ── Helpers ──────────────────────────────────────────────────────────

// Create a fake DOM element (duck-typed to match the nodeType + tagName check)
let makeElement: (string, ~id: string=?, ~className: string=?, ~textContent: string=?, unit) => 'a = %raw(`
  function(tag, id, className, textContent) {
    return {
      nodeType: 1,
      tagName: tag,
      id: id || '',
      className: className || '',
      textContent: textContent || ''
    };
  }
`)

// Create a fake NodeList (duck-typed: has .item function and .length)
let makeNodeList: array<'a> => 'a = %raw(`
  function(items) {
    var nl = {
      length: items.length,
      item: function(i) { return items[i] || null; }
    };
    for (var i = 0; i < items.length; i++) nl[i] = items[i];
    return nl;
  }
`)

// Create a circular reference object
let makeCircular: unit => 'a = %raw(`
  function() {
    var obj = { name: 'root' };
    obj.self = obj;
    return obj;
  }
`)

// Create a deeply nested object to a given depth
let makeDeeplyNested: int => 'a = %raw(`
  function(depth) {
    var obj = { value: 'leaf' };
    for (var i = 0; i < depth; i++) {
      obj = { child: obj };
    }
    return obj;
  }
`)

// Create an object with many keys
let makeWideObject: int => 'a = %raw(`
  function(count) {
    var obj = {};
    for (var i = 0; i < count; i++) {
      obj['key' + i] = i;
    }
    return obj;
  }
`)

// ── Primitives ───────────────────────────────────────────────────────

describe("SmartSerialize - primitives", () => {
  test("serializes numbers", t => {
    t->expect(SmartSerialize.serialize(42, 10000))->Expect.toBe("42")
  })

  test("serializes strings", t => {
    t->expect(SmartSerialize.serialize("hello", 10000))->Expect.toBe(`"hello"`)
  })

  test("serializes booleans", t => {
    t->expect(SmartSerialize.serialize(true, 10000))->Expect.toBe("true")
  })

  test("serializes null", t => {
    t->expect(SmartSerialize.serialize(Nullable.null, 10000))->Expect.toBe("null")
  })

  test("serializes undefined as 'undefined'", t => {
    t->expect(SmartSerialize.serialize(Nullable.undefined, 10000))->Expect.toBe("undefined")
  })

  test("serializes BigInt as string with 'n' suffix", t => {
    let bigint: 'a = %raw(`BigInt(9007199254740991)`)
    t->expect(SmartSerialize.serialize(bigint, 10000))->Expect.toBe(`"9007199254740991n"`)
  })
})

// ── Objects and arrays ───────────────────────────────────────────────

describe("SmartSerialize - objects and arrays", () => {
  test("serializes plain objects", t => {
    let result = SmartSerialize.serialize({"a": 1, "b": 2}, 10000)
    t->expect(result)->Expect.toBe(`{"a":1,"b":2}`)
  })

  test("serializes arrays", t => {
    let result = SmartSerialize.serialize([1, 2, 3], 10000)
    t->expect(result)->Expect.toBe("[1,2,3]")
  })

  test("serializes nested objects", t => {
    let result = SmartSerialize.serialize({"outer": {"inner": "value"}}, 10000)
    t->expect(result)->Expect.toBe(`{"outer":{"inner":"value"}}`)
  })
})

// ── Functions ────────────────────────────────────────────────────────

// %raw blocks can't reference ReScript module bindings, so we create
// JS function values and pass them to the ReScript-level serialize call.
let makeNamedFn: unit => 'a = %raw(`function() { function myFunc() {} return myFunc; }`)
let makeAnonFn: unit => 'a = %raw(`function() { return function() {}; }`)

describe("SmartSerialize - functions", () => {
  test("serializes named functions as placeholder", t => {
    let result = SmartSerialize.serialize(makeNamedFn(), 10000)
    t->expect(result)->Expect.toBe(`"[Function: myFunc]"`)
  })

  test("serializes anonymous functions", t => {
    let result = SmartSerialize.serialize(makeAnonFn(), 10000)
    t->expect(result)->Expect.toBe(`"[Function: anonymous]"`)
  })
})

// ── DOM elements ─────────────────────────────────────────────────────

describe("SmartSerialize - DOM elements", () => {
  test("serializes element with tag and id", t => {
    let el = makeElement("DIV", ~id="main", ())
    let result = SmartSerialize.serialize(el, 10000)
    let parsed = JSON.parseOrThrow(result)
    let obj = JSON.Decode.object(parsed)->Option.getOrThrow
    t->expect(obj->Dict.get("__type")->Option.flatMap(JSON.Decode.string))->Expect.toEqual(Some("Element"))
    t->expect(obj->Dict.get("tag")->Option.flatMap(JSON.Decode.string))->Expect.toEqual(Some("DIV"))
    t->expect(obj->Dict.get("id")->Option.flatMap(JSON.Decode.string))->Expect.toEqual(Some("main"))
  })

  test("serializes element with className", t => {
    let el = makeElement("SPAN", ~className="btn btn-primary", ())
    let result = SmartSerialize.serialize(el, 10000)
    let parsed = JSON.parseOrThrow(result)
    let obj = JSON.Decode.object(parsed)->Option.getOrThrow
    t->expect(obj->Dict.get("className")->Option.flatMap(JSON.Decode.string))->Expect.toEqual(Some("btn btn-primary"))
  })

  test("truncates textContent to 80 chars", t => {
    let longText = "A"->String.repeat(120)
    let el = makeElement("P", ~textContent=longText, ())
    let result = SmartSerialize.serialize(el, 10000)
    let parsed = JSON.parseOrThrow(result)
    let obj = JSON.Decode.object(parsed)->Option.getOrThrow
    let tc = obj->Dict.get("textContent")->Option.flatMap(JSON.Decode.string)->Option.getOrThrow
    t->expect(String.length(tc))->Expect.toBe(80)
  })
})

// ── NodeList ─────────────────────────────────────────────────────────

describe("SmartSerialize - NodeList", () => {
  test("serializes NodeList as array", t => {
    let nl = makeNodeList([
      makeElement("LI", ~textContent="one", ()),
      makeElement("LI", ~textContent="two", ()),
    ])
    let result = SmartSerialize.serialize(nl, 10000)
    let parsed = JSON.parseOrThrow(result)
    let arr = JSON.Decode.array(parsed)->Option.getOrThrow
    t->expect(Array.length(arr))->Expect.toBe(2)
  })
})

// ── Map and Set ──────────────────────────────────────────────────────

let makeMap: unit => 'a = %raw(`function() { var m = new Map(); m.set('a', 1); m.set('b', 2); return m; }`)
let makeSet: unit => 'a = %raw(`function() { var s = new Set(); s.add('x'); s.add('y'); s.add('z'); return s; }`)

describe("SmartSerialize - Map and Set", () => {
  test("serializes Map with __type marker", t => {
    let result = SmartSerialize.serialize(makeMap(), 10000)
    let parsed = JSON.parseOrThrow(result)
    let obj = JSON.Decode.object(parsed)->Option.getOrThrow
    t->expect(obj->Dict.get("__type")->Option.flatMap(JSON.Decode.string))->Expect.toEqual(Some("Map"))
    let entries = obj->Dict.get("entries")->Option.flatMap(JSON.Decode.array)->Option.getOrThrow
    t->expect(Array.length(entries))->Expect.toBe(2)
  })

  test("serializes Set with __type marker", t => {
    let result = SmartSerialize.serialize(makeSet(), 10000)
    let parsed = JSON.parseOrThrow(result)
    let obj = JSON.Decode.object(parsed)->Option.getOrThrow
    t->expect(obj->Dict.get("__type")->Option.flatMap(JSON.Decode.string))->Expect.toEqual(Some("Set"))
    let values = obj->Dict.get("values")->Option.flatMap(JSON.Decode.array)->Option.getOrThrow
    t->expect(Array.length(values))->Expect.toBe(3)
  })
})

// ── Circular references ──────────────────────────────────────────────

describe("SmartSerialize - circular references", () => {
  test("replaces circular refs with [Circular]", t => {
    let obj = makeCircular()
    let result = SmartSerialize.serialize(obj, 10000)
    t->expect(String.includes(result, "[Circular]"))->Expect.toBe(true)
  })
})

// ── Depth and breadth limits ─────────────────────────────────────────

describe("SmartSerialize - depth and breadth limits", () => {
  test("caps depth at 5 levels with [Object] placeholder", t => {
    let obj = makeDeeplyNested(10)
    let result = SmartSerialize.serialize(obj, 10000)
    t->expect(String.includes(result, "[Object]"))->Expect.toBe(true)
  })

  test("caps breadth at 50 keys", t => {
    let obj = makeWideObject(60)
    let result = SmartSerialize.serialize(obj, 10000)
    t->expect(String.includes(result, "__truncated"))->Expect.toBe(true)
    t->expect(String.includes(result, "10 more keys"))->Expect.toBe(true)
  })
})

// ── Output truncation ────────────────────────────────────────────────

describe("SmartSerialize - output truncation", () => {
  test("truncates output exceeding maxBytes", t => {
    let obj = makeWideObject(100)
    let result = SmartSerialize.serialize(obj, 200)
    t->expect(String.includes(result, "...[truncated]"))->Expect.toBe(true)
    // 200 bytes + the truncation marker
    t->expect(String.length(result) <= 200 + String.length("...[truncated]"))->Expect.toBe(true)
  })
})
