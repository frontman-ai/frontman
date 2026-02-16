// Templates for generated files
module Style = FrontmanAstro__Cli__Style

// ASCII art banner for the installer
let banner = () => {
  let l1 = Style.purpleBold("   ___              _                       ")
  let l2 = Style.purpleBold("  | __| _ ___ _ _ | |_ _ __  __ _ _ _  ")
  // Use double-quoted string for the backtick line
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

// src/middleware.ts template
let middlewareTemplate = (host: string) =>
  `import { createMiddleware, makeConfig } from '@frontman-ai/astro';
import { defineMiddleware } from 'astro:middleware';

const config = makeConfig({ host: '${host}' });
const frontman = createMiddleware(config);

export const onRequest = defineMiddleware(async (context, next) => {
  return frontman(context, next);
});
`

// astro.config.mjs template (for clean projects with no existing config)
let configTemplate = (host: string) => {
  // host is unused in the config template (it's used via makeConfig in middleware),
  // but we accept it to keep the API consistent and for future use
  ignore(host)
  `import { defineConfig } from 'astro/config';
import node from '@astrojs/node';
import { frontmanIntegration } from '@frontman-ai/astro';

const isProd = process.env.NODE_ENV === 'production';

export default defineConfig({
  // SSR needed in dev for Frontman middleware routes
  ...(isProd ? {} : { output: 'server', adapter: node({ mode: 'standalone' }) }),
  integrations: [frontmanIntegration()],
});
`
}

// Manual setup instructions (shown in summary when auto-edit is skipped)
module ManualInstructions = {
  let config = (fileName: string, _host: string) => {
    let h = Style.yellowBold
    let s = Style.purple
    let d = Style.dim
    let b = Style.bold
    let bar = Style.yellow("|")

    `  ${bar}
  ${bar}  ${h(fileName)} needs manual modification.
  ${bar}
  ${bar}  ${s("1.")} Add imports at the top of the file:
  ${bar}
  ${bar}     ${d("import node from '@astrojs/node';")}
  ${bar}     ${d("import { frontmanIntegration } from '@frontman-ai/astro';")}
  ${bar}
  ${bar}  ${s("2.")} Add SSR config for dev mode ${d("(needed for middleware routes)")}:
  ${bar}
  ${bar}     ${d("const isProd = process.env.NODE_ENV === 'production';")}
  ${bar}
  ${bar}     ${d("export default defineConfig({")}
  ${bar}     ${d("  ...(isProd ? {} : { output: 'server', adapter: node({ mode: 'standalone' }) }),")}
  ${bar}     ${d("  // ... your existing config")}
  ${bar}     ${d("});")}
  ${bar}
  ${bar}  ${s("3.")} Add ${b("frontmanIntegration()")} to your integrations array:
  ${bar}
  ${bar}     ${d("integrations: [frontmanIntegration(), ...yourExistingIntegrations]")}
  ${bar}
  ${bar}  ${b("Docs:")} ${d("https://frontman.sh/docs/astro")}
  ${bar}`
  }

  let middleware = (fileName: string, host: string) => {
    let h = Style.yellowBold
    let s = Style.purple
    let d = Style.dim
    let b = Style.bold
    let bar = Style.yellow("|")

    `  ${bar}
  ${bar}  ${h(fileName)} needs manual modification.
  ${bar}
  ${bar}  ${s("1.")} Add imports at the top of the file:
  ${bar}
  ${bar}     ${d("import { createMiddleware, makeConfig } from '@frontman-ai/astro';")}
  ${bar}     ${d("import { defineMiddleware, sequence } from 'astro:middleware';")}
  ${bar}
  ${bar}  ${s("2.")} Create the Frontman middleware instance ${d("(after imports)")}:
  ${bar}
  ${bar}     ${d(`const frontmanConfig = makeConfig({ host: '${host}' });`)}
  ${bar}     ${d("const frontman = createMiddleware(frontmanConfig);")}
  ${bar}
  ${bar}  ${s("3.")} Combine with your existing middleware using ${b("sequence()")}:
  ${bar}
  ${bar}     ${d("const frontmanMiddleware = defineMiddleware(async (context, next) => {")}
  ${bar}     ${d("  return frontman(context, next);")}
  ${bar}     ${d("});")}
  ${bar}
  ${bar}     ${d("export const onRequest = sequence(frontmanMiddleware, yourExistingMiddleware);")}
  ${bar}
  ${bar}  ${b("Docs:")} ${d("https://frontman.sh/docs/astro")}
  ${bar}`
  }
}

// Keep plain-text versions for the LLM system prompt (no ANSI codes)
module ErrorMessages = {
  let configManualSetup = (fileName: string, _host: string) =>
    `
${fileName} already exists and requires manual modification.

Add the following to your ${fileName}:

  1. Add imports at the top of the file:

     import node from '@astrojs/node';
     import { frontmanIntegration } from '@frontman-ai/astro';

  2. Add SSR config for dev mode (needed for middleware routes):

     const isProd = process.env.NODE_ENV === 'production';

     export default defineConfig({
       ...(isProd ? {} : { output: 'server', adapter: node({ mode: 'standalone' }) }),
       // ... your existing config
     });

  3. Add frontmanIntegration() to your integrations array:

     integrations: [frontmanIntegration(), ...yourExistingIntegrations],

For full documentation, see: https://frontman.sh/docs/astro
`

  let middlewareManualSetup = (fileName: string, host: string) =>
    `
${fileName} already exists and requires manual modification.

Add the following to your ${fileName}:

  1. Add imports at the top of the file:

     import { createMiddleware, makeConfig } from '@frontman-ai/astro';
     import { defineMiddleware, sequence } from 'astro:middleware';

  2. Create the Frontman middleware instance (after imports):

     const frontmanConfig = makeConfig({ host: '${host}' });
     const frontman = createMiddleware(frontmanConfig);

  3. Combine with your existing middleware using sequence():

     const frontmanMiddleware = defineMiddleware(async (context, next) => {
       return frontman(context, next);
     });

     export const onRequest = sequence(frontmanMiddleware, yourExistingMiddleware);

For full documentation, see: https://frontman.sh/docs/astro
`
}

// Success messages
module SuccessMessages = {
  let fileCreated = (fileName: string) =>
    `  ${Style.check} Created ${Style.bold(fileName)}`

  let fileSkipped = (fileName: string) =>
    `  ${Style.purple("–")} Skipped ${Style.bold(fileName)} ${Style.dim("(already configured)")}`

  let hostUpdated = (fileName: string, oldHost: string, newHost: string) =>
    `  ${Style.check} Updated ${Style.bold(fileName)} ${Style.dim(`(host: '${oldHost}' -> '${newHost}')`)}`

  let fileAutoEdited = (fileName: string) =>
    `  ${Style.check} Auto-edited ${Style.bold(fileName)} ${Style.dim("(Frontman integrated via AI)")}`

  let autoEditFailed = (fileName: string, error: string) =>
    `  ${Style.warn}  Auto-edit failed for ${Style.bold(fileName)}: ${Style.dim(error)}`

  let manualEditRequired = (fileName: string) =>
    `  ${Style.warn}  ${Style.bold(fileName)} requires manual setup ${Style.dim("(see details below)")}`

  let installComplete = (~devCommand: string) => {
    let p = Style.purple
    let pb = Style.purpleBold
    let d = Style.dim
    let pd = Style.purpleDim

    `
  ${pb("Frontman setup complete!")}

  ${pb("Next steps:")}
    ${p("1.")} Start your dev server   ${d(devCommand)}
    ${p("2.")} Open your browser to    ${d("http://localhost:4321/frontman")}

  ${p("┌───────────────────────────────────────────────┐")}
  ${p("│")}                                               ${p("│")}
  ${p("│")}   Questions? Comments? Need support?          ${p("│")}
  ${p("│")}                                               ${p("│")}
  ${p("│")}       Join us on Discord:                     ${p("│")}
  ${p("│")}       ${pd("https://discord.gg/J77jBzMM")}             ${p("│")}
  ${p("│")}                                               ${p("│")}
  ${p("└───────────────────────────────────────────────┘")}
`
  }

  let dryRunHeader =
    `  ${Style.warn}  ${Style.yellowBold("DRY RUN MODE")} ${Style.dim("— No files will be created")}
`
}
