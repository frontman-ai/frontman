open Vitest

let storage = () => WebAPI.Window.current->WebAPI.Window.localStorage
let headersDict = (headers: WebAPI.HeadersInit.t): Dict.t<string> => Obj.magic(headers)

describe("EmbeddedAuth", () => {
  beforeEach(() => {
    storage()->WebAPI.Storage.removeItem(Client__EmbeddedAuth.tokenStorageKey)
  })

  afterEach(() => {
    storage()->WebAPI.Storage.removeItem(Client__EmbeddedAuth.tokenStorageKey)
  })

  test("stores and loads the embedded client token", t => {
    Client__EmbeddedAuth.saveToken("token-123")

    t->expect(Client__EmbeddedAuth.loadToken())->Expect.toBe(Some("token-123"))
  })

  test("clears the embedded client token", t => {
    Client__EmbeddedAuth.saveToken("token-123")
    Client__EmbeddedAuth.clearToken()

    t->expect(Client__EmbeddedAuth.loadToken())->Expect.toBe(None)
  })

  test("builds bearer authorization headers", t => {
    Client__EmbeddedAuth.saveToken("token-123")

    let headers = Client__EmbeddedAuth.headers()->Option.getOrThrow->headersDict

    t->expect(headers->Dict.get("Authorization"))->Expect.toBe(Some("Bearer token-123"))
  })

  test("adds json content type when requested", t => {
    Client__EmbeddedAuth.saveToken("token-123")

    let headers = Client__EmbeddedAuth.jsonHeaders()->Option.getOrThrow->headersDict

    t->expect(headers->Dict.get("Authorization"))->Expect.toBe(Some("Bearer token-123"))
    t->expect(headers->Dict.get("Content-Type"))->Expect.toBe(Some("application/json"))
  })

  test("omits headers when no token is stored", t => {
    t->expect(Client__EmbeddedAuth.headers())->Expect.toBe(None)
    t->expect(Client__EmbeddedAuth.jsonHeaders())->Expect.toBe(None)
  })
})
