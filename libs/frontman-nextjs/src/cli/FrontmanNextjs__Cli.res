// CLI entry point for frontman-nextjs
// Usage: npx @frontman-ai/nextjs install --server <host>

module Process = FrontmanBindings.Process
module Hosts = FrontmanFrontmanCore.FrontmanCore__Hosts
module Install = FrontmanNextjs__Cli__Install

// Parse command line arguments (simple implementation without external deps)
type parsedArgs = {
  command: option<string>,
  server: option<string>,
  prefix: option<string>,
  dryRun: bool,
  skipDeps: bool,
  help: bool,
}

let helpText = `
Frontman NextJS CLI

Usage:
  frontman-nextjs <command> [options]

Commands:
  install    Install Frontman in a Next.js project

Options:
  --server <host>   Frontman server host (default: api.frontman.sh)
  --prefix <path>   Target directory (default: current directory)
  --dry-run         Preview changes without writing files
  --skip-deps       Skip dependency installation
  --help            Show this help message

Examples:
  npx @frontman-ai/nextjs install
  npx @frontman-ai/nextjs install --server frontman.company.com
  npx @frontman-ai/nextjs install --dry-run
`

// Simple argument parser
let parseArgs = (argv: array<string>): parsedArgs => {
  // Skip node and script path (argv[0] and argv[1])
  let args = argv->Array.slice(~start=2, ~end=Array.length(argv))

  let rec parse = (
    ~remaining: array<string>,
    ~result: parsedArgs,
  ): parsedArgs => {
    switch remaining->Array.get(0) {
    | None => result
    | Some(arg) =>
      let rest = remaining->Array.slice(~start=1, ~end=Array.length(remaining))

      switch arg {
      | "install" => parse(~remaining=rest, ~result={...result, command: Some("install")})
      | "--server" =>
        let value = rest->Array.get(0)
        let nextRest = rest->Array.slice(~start=1, ~end=Array.length(rest))
        parse(~remaining=nextRest, ~result={...result, server: value})
      | "--prefix" =>
        let value = rest->Array.get(0)
        let nextRest = rest->Array.slice(~start=1, ~end=Array.length(rest))
        parse(~remaining=nextRest, ~result={...result, prefix: value})
      | "--dry-run" => parse(~remaining=rest, ~result={...result, dryRun: true})
      | "--skip-deps" => parse(~remaining=rest, ~result={...result, skipDeps: true})
      | "--help" | "-h" => parse(~remaining=rest, ~result={...result, help: true})
      | _ => parse(~remaining=rest, ~result)
      }
    }
  }

  parse(
    ~remaining=args,
    ~result={
      command: None,
      server: None,
      prefix: None,
      dryRun: false,
      skipDeps: false,
      help: false,
    },
  )
}

// Main entry point
let main = async () => {
  let args = parseArgs(Process.argv)

  switch args.help {
  | true =>
    Console.log(helpText)
    Process.exit(0)
  | false => ()
  }

  switch args.command {
  | Some("install") =>
    let server = args.server->Option.getOr(Hosts.apiHost)
    let result = await Install.run({
      server,
      prefix: args.prefix,
      dryRun: args.dryRun,
      skipDeps: args.skipDeps,
    })

    switch result {
    | Install.Success => Process.exit(0)
    | Install.PartialSuccess(_) => Process.exit(0) // Still success, just with manual steps
    | Install.Failure(_) => Process.exit(1)
    }

  | Some(cmd) =>
    Console.error(`Unknown command: ${cmd}`)
    Console.log(helpText)
    Process.exit(1)

  | None =>
    Console.log(helpText)
    Process.exit(0)
  }
}

// Run main
main()->ignore
