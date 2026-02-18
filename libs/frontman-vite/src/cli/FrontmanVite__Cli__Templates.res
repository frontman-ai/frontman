// Templates for generated/modified files
module Style = FrontmanVite__Cli__Style

// ASCII art banner for the installer
let banner = () => {
  let l1 = Style.purpleBold("   ___              _                       ")
  let l2 = Style.purpleBold("  | __| _ ___ _ _ | |_ _ __  __ _ _ _  ")
  let l3 = Style.purpleBold("  | _| '_/ _ \\ ' \\|  _| '  \\/ _` | ' \\ ")
  let l4 = Style.purpleBold("  |_||_| \\___/_||_|\\__|_|_|_\\__,_|_||_|")
  let tagline = Style.purpleDim("  AI that sees your DOM and edits your frontend")

  `
${l1}
${l2}
${l3}
${l4}

${tagline}
`
}

// The import line to inject into vite.config
let importLine = `import { frontmanPlugin } from '@frontman-ai/vite';`

// The plugin call with host option
let pluginCall = (~server: string) =>
  `frontmanPlugin({ host: '${server}' })`

// Manual instructions shown when user has an existing config and skips auto-edit
module ManualInstructions = {
  let viteConfig = (~server: string, fileName: string) => {
    let h = Style.yellowBold
    let s = Style.purple
    let d = Style.dim
    let b = Style.bold
    let bar = Style.yellow("|")
    let call = pluginCall(~server)

    `  ${bar}
  ${bar}  ${h(fileName)} needs manual modification.
  ${bar}
  ${bar}  ${s("1.")} Add import at the top of the file:
  ${bar}
  ${bar}     ${d("import { frontmanPlugin } from '@frontman-ai/vite';")}
  ${bar}
  ${bar}  ${s("2.")} Add ${b(call)} to your plugins array:
  ${bar}
  ${bar}     ${d("plugins: [")}
  ${bar}     ${d(`  ${call},`)}
  ${bar}     ${d("  // ...your other plugins")}
  ${bar}     ${d("],")}
  ${bar}
  ${bar}  ${b("Docs:")} ${d("https://frontman.sh/docs/vite")}
  ${bar}`
  }
}

// Success messages
module SuccessMessages = {
  let fileCreated = (fileName: string) =>
    `  ${Style.check} Created ${Style.bold(fileName)}`

  let fileUpdated = (fileName: string) =>
    `  ${Style.check} Updated ${Style.bold(fileName)} ${Style.dim("(added frontmanPlugin)")}`

  let fileSkipped = (fileName: string) =>
    `  ${Style.purple("–")} Skipped ${Style.bold(fileName)} ${Style.dim("(already configured)")}`

  let manualEditRequired = (fileName: string) =>
    `  ${Style.warn}  ${Style.bold(fileName)} requires manual setup ${Style.dim("(see details below)")}`

  let installComplete = (~devCommand: string, ~port: string) => {
    let p = Style.purple
    let pb = Style.purpleBold
    let d = Style.dim

    `
  ${pb("Frontman setup complete!")}

  ${pb("Next steps:")}
    ${p("1.")} Start your dev server   ${d(devCommand)}
    ${p("2.")} Open your browser to    ${d(`http://localhost:${port}/frontman`)}

  ${p("┌───────────────────────────────────────────────┐")}
  ${p("│                                               │")}
  ${p("│   Questions? Comments? Need support?          │")}
  ${p("│                                               │")}
  ${p("│       Join us on Discord:                     │")}
  ${p("│       https://discord.gg/xk8uXJSvhC           │")}
  ${p("│                                               │")}
  ${p("└───────────────────────────────────────────────┘")}
`
  }

  let dryRunHeader =
    `  ${Style.warn}  ${Style.yellowBold("DRY RUN MODE")} ${Style.dim("— No files will be created")}
`
}
