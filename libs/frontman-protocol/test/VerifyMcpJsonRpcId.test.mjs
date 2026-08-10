import assert from "node:assert/strict"
import {readFile} from "node:fs/promises"
import test from "node:test"
import * as S from "sury/src/S.res.mjs"
import {Id, Request, Response} from "../src/FrontmanProtocol__JsonRpc.res.mjs"
import {createOracle} from "../scripts/VerifyMcpOracle.mjs"

const upstreamSchema = JSON.parse(await readFile(new URL("mcp-upstream/schema.json", import.meta.url)))
const oracle = createOracle(upstreamSchema)

const parse = value => S.parseOrThrow(value, Id.schema)

test("JSON-RPC IDs preserve every supported wire value", () => {
  const values = [
    "",
    "request-9007199254740991",
    0,
    -1,
    2147483648,
    Number.MIN_SAFE_INTEGER,
    Number.MAX_SAFE_INTEGER,
  ]

  for (const value of values) {
    const parsed = parse(value)
    assert.strictEqual(Id.toJson(parsed), value)
    assert.equal(oracle.validate("RequestId", Id.toJson(parsed)).valid, true)
  }
})

test("JSON-RPC envelopes preserve string and wide numeric IDs", () => {
  for (const id of ["request-id", 9007199254740991]) {
    const request = S.parseOrThrow({jsonrpc: "2.0", id, method: "tools/list"}, Request.schema)
    assert.strictEqual(Request.toJson(request).id, id)

    const response = Response.fromJsonExn({jsonrpc: "2.0", id, result: {resultType: "complete"}})
    assert.strictEqual(Id.toJson(Response.id(response)), id)
  }
})

test("JSON-RPC ID schema rejects values outside the upstream domain", () => {
  const values = [null, true, 1.5, {}, [], Number.NaN, Number.POSITIVE_INFINITY]

  for (const value of values) {
    assert.throws(() => parse(value))
    assert.equal(oracle.validate("RequestId", value).valid, false)
  }
})

test("JSON-RPC ID schema rejects unsafe integers accepted by upstream", () => {
  for (const value of [Number.MIN_SAFE_INTEGER - 1, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => parse(value))
    assert.equal(oracle.validate("RequestId", value).valid, true)
  }
})
