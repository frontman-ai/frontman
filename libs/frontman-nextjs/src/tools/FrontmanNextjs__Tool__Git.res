// Git tool - run a git command in the project (status, branch, add, commit, push, ...).
// Native Next.js tool (bundles reliably like get_routes/get_logs). Spawns `git` directly
// with an args array (NO shell -> no injection), in the project source root.
//
// SECURITY POLICY (defence in depth on top of the access=Write approval boundary):
// even without a shell, arbitrary git arguments can execute programs — e.g.
//   git -c core.sshCommand=...        git -c core.pager=...
//   git fetch --upload-pack=...       git push --receive-pack=...
//   git ... --exec=...                aliases / hooks / credential helpers
// so we validate BEFORE spawning:
//   1. args must be non-empty; the first token is the subcommand.
//   2. NO global option may precede the subcommand — this blocks `-c`,
//      `--config-env`, `-C`, `--git-dir`, `--work-tree`, `--exec-path`,
//      `--namespace`, ... in one rule (all git config-injection vectors are
//      global options that come before the subcommand).
//   3. the subcommand must be on an allowlist scoped to the agent's
//      branch / commit / push workflow.
//   4. a denylist rejects program-executing options anywhere in the args
//      (`--upload-pack`, `--receive-pack`, `--exec`).
// Repo-local hooks still run as part of normal git operation; they belong to the
// checked-out project the agent is already editing, so they are in-scope of the
// user's approval rather than something this tool can or should strip.

module ChildProcess = FrontmanAiFrontmanCore.FrontmanCore__ChildProcess
module Tool = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool

let name = "git"
let access = Tool.Write
let visibleToAgent = true

// Subcommands the agent is allowed to run. Curated to read + local history +
// branch/commit/push/sync. Deliberately excludes anything designed to run
// arbitrary programs or reach outside the repo (`config`, `clone`, `submodule`,
// `bundle`, `daemon`, `fast-import`, `filter-branch`, `am`, `apply`, `worktree`).
let allowedSubcommands = [
  "status",
  "log",
  "diff",
  "show",
  "branch",
  "checkout",
  "switch",
  "add",
  "restore",
  "commit",
  "push",
  "fetch",
  "pull",
  "merge",
  "merge-base",
  "rev-parse",
  "remote",
  "stash",
  "reset",
  "tag",
  "describe",
  "ls-files",
  "ls-remote",
  "cherry-pick",
  "revert",
  "blame",
  "shortlog",
]

// Options that can make git execute an arbitrary program, wherever they appear
// (after the subcommand). Global config-injection options are already blocked by
// rule 2, since they must precede the subcommand.
let deniedOptionPrefixes = ["--upload-pack", "--receive-pack", "--exec"]

let isDeniedOption = (arg: string): bool =>
  deniedOptionPrefixes->Array.some(p => arg === p || arg->String.startsWith(p ++ "="))

// Returns Ok(subcommand) when the args are allowed, or Error(message) explaining
// why they were rejected (surfaced to the agent so it can adjust).
let validate = (args: array<string>): result<string, string> => {
  switch args->Array.get(0) {
  | None => Error(`git: no arguments provided. Pass the subcommand first, e.g. ["status", "--porcelain"].`)
  | Some(first) =>
    if first->String.startsWith("-") {
      Error(
        `git: global options before the subcommand are not allowed (got "${first}"). ` ++
        `Put the subcommand first, e.g. ["log", "--oneline"].`,
      )
    } else if !(allowedSubcommands->Array.includes(first)) {
      Error(
        `git: subcommand "${first}" is not allowed. Allowed: ${allowedSubcommands->Array.join(", ")}.`,
      )
    } else {
      switch args->Array.find(isDeniedOption) {
      | Some(bad) =>
        Error(`git: option "${bad}" is not allowed (it can execute an arbitrary program).`)
      | None => Ok(first)
      }
    }
  }
}

let description = `Run a git command in the project directory.

Provide the git arguments as an array; the leading "git" is implied and must be omitted.
Examples:
- ["status", "--porcelain"]
- ["checkout", "-b", "my-feature"]
- ["add", "components/Foo.tsx"]
- ["commit", "-m", "Update Foo"]
- ["push", "-u", "origin", "my-feature"]

Runs with NO shell — arguments are passed straight to git, so quoting/escaping and shell
injection are not a concern (do NOT wrap the whole command in one string). Only the git
binary is executed.

For safety, arguments are validated before running:
- The FIRST argument must be the git subcommand (no global options like -c/-C/--git-dir
  before it).
- Only a fixed allowlist of subcommands is permitted (status, log, diff, show, branch,
  checkout, switch, add, restore, commit, push, fetch, pull, merge, merge-base, rev-parse,
  remote, stash, reset, tag, describe, ls-files, ls-remote, cherry-pick, revert, blame,
  shortlog).
- Program-executing options (--upload-pack, --receive-pack, --exec) are rejected.
A rejected or non-zero command comes back as success:false with the reason in stderr — read
it and adjust, do not retry blindly.`

@schema
type input = {
  args: array<string>,
}

@schema
type output = {
  @live success: bool,
  @live stdout: string,
  @live stderr: string,
}

let executeOutput = async (ctx: Tool.serverExecutionContext, input: input): output => {
  switch validate(input.args) {
  | Error(msg) => {success: false, stdout: "", stderr: msg}
  | Ok(_) =>
    switch await ChildProcess.spawnResult("git", input.args, ~cwd=ctx.sourceRoot) {
    | Ok(res) => {success: true, stdout: res.stdout, stderr: res.stderr}
    | Error(err) => {success: false, stdout: err.stdout, stderr: err.stderr}
    }
  }
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.MCP.CallToolResult.t => {
  let out = await executeOutput(ctx, input)
  Tool.jsonResult(out, outputSchema)
}
