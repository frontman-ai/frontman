// Templates for generated files
module Style = FrontmanNextjs__Cli__Style

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

// middleware.ts template for Next.js 15 and earlier
let middlewareTemplate = (host: string) =>
  `import { createMiddleware } from '@frontman-ai/nextjs';
import { NextRequest, NextResponse } from 'next/server';

const frontman = createMiddleware({
  host: '${host}',
});

export async function middleware(req: NextRequest) {
  const response = await frontman(req);
  if (response) return response;
  return NextResponse.next();
}

export const config = {
  matcher: ['/frontman', '/frontman/:path*', '/:path*/frontman'],
};
`

// proxy.ts template for Next.js 16+
let proxyTemplate = (host: string) =>
  `import { createMiddleware } from '@frontman-ai/nextjs';
import { NextRequest, NextResponse } from 'next/server';

const frontman = createMiddleware({
  host: '${host}',
});

export function proxy(req: NextRequest): NextResponse | Promise<NextResponse> {
  if (req.nextUrl.pathname === '/frontman' || req.nextUrl.pathname.startsWith('/frontman/') || req.nextUrl.pathname.endsWith('/frontman')) {
    return frontman(req) || NextResponse.next();
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/frontman', '/frontman/:path*', '/:path*/frontman'],
};
`

// instrumentation.ts template
let instrumentationTemplate = () =>
  `export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const { NodeSDK } = await import('@opentelemetry/sdk-node');
    const { setup } = await import('@frontman-ai/nextjs/Instrumentation');
    const [logProcessor, spanProcessor] = setup();
    new NodeSDK({
      logRecordProcessors: [logProcessor],
      spanProcessors: [spanProcessor],
    }).start();
  }
}
`

// Manual setup instructions (shown in summary when auto-edit is skipped)
module ManualInstructions = {
  let middleware = (fileName: string, host: string) => {
    let h = Style.yellowBold
    let s = Style.purple
    let d = Style.dim
    let b = Style.bold
    let bar = Style.yellow("|")

    `  ${bar}
  ${bar}  ${h(fileName)} needs manual modification.
  ${bar}
  ${bar}  ${s("1.")} Add import at the top of the file:
  ${bar}
  ${bar}     ${d("import { createMiddleware } from '@frontman-ai/nextjs';")}
  ${bar}
  ${bar}  ${s("2.")} Create the middleware instance ${d("(after imports)")}:
  ${bar}
  ${bar}     ${d(`const frontman = createMiddleware({ host: '${host}' });`)}
  ${bar}
  ${bar}  ${s("3.")} In your middleware function, add at the beginning:
  ${bar}
  ${bar}     ${d("const response = await frontman(req);")}
  ${bar}     ${d("if (response) return response;")}
  ${bar}
  ${bar}  ${s("4.")} Update your matcher config to include Frontman routes:
  ${bar}
   ${bar}     ${d("matcher: ['/frontman', '/frontman/:path*', '/:path*/frontman', ...yourExistingMatchers]")}
  ${bar}
  ${bar}  ${b("Docs:")} ${d("https://frontman.sh/docs/nextjs")}
  ${bar}`
  }

  let proxy = (fileName: string, host: string) => {
    let h = Style.yellowBold
    let s = Style.purple
    let d = Style.dim
    let b = Style.bold
    let bar = Style.yellow("|")

    `  ${bar}
  ${bar}  ${h(fileName)} needs manual modification.
  ${bar}
  ${bar}  ${s("1.")} Add import at the top of the file:
  ${bar}
  ${bar}     ${d("import { createMiddleware } from '@frontman-ai/nextjs';")}
  ${bar}
  ${bar}  ${s("2.")} Create the middleware instance ${d("(after imports)")}:
  ${bar}
  ${bar}     ${d(`const frontman = createMiddleware({ host: '${host}' });`)}
  ${bar}
  ${bar}  ${s("3.")} In your proxy function, add Frontman handler at the beginning:
  ${bar}
     ${bar}     ${d("if (req.nextUrl.pathname === '/frontman' || req.nextUrl.pathname.startsWith('/frontman/') || req.nextUrl.pathname.endsWith('/frontman')) {")}
  ${bar}     ${d("  return frontman(req) || NextResponse.next();")}
  ${bar}     ${d("}")}
  ${bar}
  ${bar}  ${s("4.")} Update your matcher config to include Frontman routes:
  ${bar}
  ${bar}     ${d("matcher: ['/frontman', '/frontman/:path*', '/:path*/frontman', ...yourExistingMatchers]")}
  ${bar}
  ${bar}  ${b("Docs:")} ${d("https://frontman.sh/docs/nextjs")}
  ${bar}`
  }

  let instrumentation = (fileName: string) => {
    let h = Style.yellowBold
    let s = Style.purple
    let d = Style.dim
    let b = Style.bold
    let bar = Style.yellow("|")

    `  ${bar}
  ${bar}  ${h(fileName)} needs manual modification.
  ${bar}
  ${bar}  ${s("1.")} If you ${b("don't")} have OpenTelemetry set up yet, add inside register():
  ${bar}
  ${bar}     ${d("const { NodeSDK } = await import('@opentelemetry/sdk-node');")}
  ${bar}     ${d("const { setup } = await import('@frontman-ai/nextjs/Instrumentation');")}
  ${bar}     ${d("const [logProcessor, spanProcessor] = setup();")}
  ${bar}     ${d("new NodeSDK({ logRecordProcessors: [logProcessor], spanProcessors: [spanProcessor] }).start();")}
  ${bar}
  ${bar}  ${s("2.")} If you ${b("already")} have OpenTelemetry, add the Frontman processors:
  ${bar}
  ${bar}     ${d("const { setup } = await import('@frontman-ai/nextjs/Instrumentation');")}
  ${bar}     ${d("const [logProcessor, spanProcessor] = setup();")}
  ${bar}     ${d("// Add to your existing NodeSDK config: logRecordProcessors, spanProcessors")}
  ${bar}
  ${bar}  ${b("Docs:")} ${d("https://frontman.sh/docs/nextjs")}
  ${bar}`
  }
}

// Keep plain-text versions for the LLM system prompt (no ANSI codes)
module ErrorMessages = {
  let middlewareManualSetup = (fileName: string, host: string) =>
    `
${fileName} already exists and requires manual modification.

Add the following to your ${fileName}:

  1. Add import at the top of the file:

     import { createMiddleware } from '@frontman-ai/nextjs';

  2. Create the middleware instance (after imports):

     const frontman = createMiddleware({
       host: '${host}',
     });

  3. In your middleware function, add at the beginning:

     export async function middleware(req: NextRequest) {
       // Add Frontman handler first
       const response = await frontman(req);
       if (response) return response;

       // ... your existing middleware logic
     }

  4. Update your matcher config to include Frontman routes:

      export const config = {
        matcher: ['/frontman', '/frontman/:path*', '/:path*/frontman', ...yourExistingMatchers],
      };

For full documentation, see: https://frontman.sh/docs/nextjs
`

  let proxyManualSetup = (fileName: string, host: string) =>
    `
${fileName} already exists and requires manual modification.

Add the following to your ${fileName}:

  1. Add import at the top of the file:

     import { createMiddleware } from '@frontman-ai/nextjs';

  2. Create the middleware instance (after imports):

     const frontman = createMiddleware({
       host: '${host}',
     });

  3. In your proxy function, add at the beginning:

      export function proxy(req: NextRequest): NextResponse | Promise<NextResponse> {
        // Add Frontman handler first
        if (req.nextUrl.pathname === '/frontman' || req.nextUrl.pathname.startsWith('/frontman/') || req.nextUrl.pathname.endsWith('/frontman')) {
         return frontman(req) || NextResponse.next();
       }

       // ... your existing proxy logic
     }

  4. Update your matcher config to include Frontman routes:

      export const config = {
        matcher: ['/frontman', '/frontman/:path*', '/:path*/frontman', ...yourExistingMatchers],
      };

For full documentation, see: https://frontman.sh/docs/nextjs
`

  let instrumentationManualSetup = (fileName: string) =>
    `
${fileName} already exists and requires manual modification.

Add the following to your ${fileName}:

  1. If you DON'T have OpenTelemetry set up yet, add inside register():

     export async function register() {
       if (process.env.NEXT_RUNTIME === 'nodejs') {
         const { NodeSDK } = await import('@opentelemetry/sdk-node');
         const { setup } = await import('@frontman-ai/nextjs/Instrumentation');
         const [logProcessor, spanProcessor] = setup();

         new NodeSDK({
           logRecordProcessors: [logProcessor],
           spanProcessors: [spanProcessor],
         }).start();
       }

       // ... your existing instrumentation logic
     }

  2. If you ALREADY have OpenTelemetry set up, add the Frontman processors:

     export async function register() {
       if (process.env.NEXT_RUNTIME === 'nodejs') {
         const { setup } = await import('@frontman-ai/nextjs/Instrumentation');
         const [logProcessor, spanProcessor] = setup();

         new NodeSDK({
           // Add Frontman processors to your existing configuration:
           logRecordProcessors: [logProcessor, ...yourExistingLogProcessors],
           spanProcessors: [spanProcessor, ...yourExistingSpanProcessors],
           // ... your other OTEL config
         }).start();
       }
     }

For full documentation, see: https://frontman.sh/docs/nextjs
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

    `
  ${pb("Frontman setup complete!")}

  ${pb("Next steps:")}
    ${p("1.")} Start your dev server   ${d(devCommand)}
    ${p("2.")} Open your browser to    ${d("http://localhost:3000/frontman")}

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
