open Vitest

module Hosts = FrontmanCore__Hosts

test("empty environment values are unconfigured", t => {
  FrontmanBindings.Process.env->Dict.set("FRONTMAN_TEST_EMPTY_ENV", " ")
  t->expect(FrontmanBindings.Process.envString("FRONTMAN_TEST_EMPTY_ENV"))->Expect.toBeNone
})

describe("clientUrl", () => {
  test("adds optional runtime parameters without overriding custom values", t => {
    [
      (
        "https://app.frontman.sh/frontman.es.js",
        Some("runtime-dsn"),
        "https://app.frontman.sh/frontman.es.js?clientName=nextjs&host=fork.example&sentryDsn=runtime-dsn",
      ),
      (
        "https://app.frontman.sh/frontman.es.js",
        None,
        "https://app.frontman.sh/frontman.es.js?clientName=nextjs&host=fork.example",
      ),
      (
        "https://cdn.example/client.js?clientName=custom&host=custom.example&sentryDsn=custom-dsn",
        Some("runtime-dsn"),
        "https://cdn.example/client.js?clientName=custom&host=custom.example&sentryDsn=custom-dsn",
      ),
    ]->Array.forEach(
      ((baseUrl, sentryDsn, expected)) => {
        let actual = Hosts.clientUrl(
          ~baseUrl=Some(baseUrl),
          ~clientName="nextjs",
          ~host="fork.example",
          ~isDev=false,
          ~sentryDsn,
          ~preserveExisting=true,
        )
        t->expect(actual)->Expect.toBe(expected)
      },
    )
  })
})
