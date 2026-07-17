// Tests for the git tool's argument-validation policy (allowlist + denylist).

open Vitest

module Git = FrontmanNextjs__Tool__Git

let expectOk = (t, args: array<string>, subcommand: string) =>
  switch Git.validate(args) {
  | Ok(sub) => t->expect(sub)->Expect.toBe(subcommand)
  | Error(msg) => t->expect("unexpected rejection: " ++ msg)->Expect.toBe("should be allowed")
  }

let expectRejected = (t, args: array<string>) =>
  switch Git.validate(args) {
  | Ok(sub) => t->expect("unexpectedly allowed: " ++ sub)->Expect.toBe("should be rejected")
  | Error(_) => t->expect(true)->Expect.toBe(true)
  }

describe("git tool - validate", _t => {
  test("allows a plain allowlisted subcommand", t => {
    t->expectOk(["status", "--porcelain"], "status")
    t->expectOk(["commit", "-m", "msg"], "commit")
    t->expectOk(["push", "-u", "origin", "my-feature"], "push")
    t->expectOk(["checkout", "-b", "my-feature"], "checkout")
  })

  test("rejects empty args", t => {
    t->expectRejected([])
  })

  test("rejects a global option before the subcommand (config injection)", t => {
    // git -c core.sshCommand=... / -c core.pager=... are RCE vectors.
    t->expectRejected(["-c", "core.sshCommand=touch /tmp/pwned", "status"])
    t->expectRejected(["-C", "/etc", "status"])
    t->expectRejected(["--git-dir=/tmp/evil", "log"])
  })

  test("rejects a subcommand that is not on the allowlist", t => {
    t->expectRejected(["clone", "https://example.com/x.git"])
    t->expectRejected(["config", "core.sshCommand", "touch /tmp/pwned"])
    t->expectRejected(["submodule", "add", "https://example.com/x.git"])
  })

  test("rejects program-executing options anywhere", t => {
    t->expectRejected(["push", "--receive-pack=/bin/sh", "origin", "main"])
    t->expectRejected(["fetch", "--upload-pack=/bin/sh", "origin"])
    t->expectRejected(["push", "--exec=/bin/sh", "origin"])
  })
})
