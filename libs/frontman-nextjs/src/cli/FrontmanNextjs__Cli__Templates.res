// Templates for generated files

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
  matcher: ['/frontman', '/frontman/:path*'],
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
  if (req.nextUrl.pathname === '/frontman' || req.nextUrl.pathname.startsWith('/frontman/')) {
    return frontman(req) || NextResponse.next();
  }
  return NextResponse.next();
}
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

// Error messages for manual setup instructions
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
        matcher: ['/frontman', '/frontman/:path*', ...yourExistingMatchers],
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
        if (req.nextUrl.pathname === '/frontman' || req.nextUrl.pathname.startsWith('/frontman/')) {
         return frontman(req) || NextResponse.next();
       }

       // ... your existing proxy logic
     }

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
  let fileCreated = (fileName: string) => `Created: ${fileName}`

  let fileSkipped = (fileName: string) => `Skipped: ${fileName} (already configured for Frontman)`

  let hostUpdated = (fileName: string, oldHost: string, newHost: string) =>
    `Updated: ${fileName} (host changed from '${oldHost}' to '${newHost}')`

  let installComplete = (host: string) =>
    `
Frontman setup complete!

Next steps:
  1. Start your Next.js dev server: npm run dev
  2. Open your browser to: http://localhost:3000/frontman
  3. Your app is now connected to: ${host}

For documentation, visit: https://frontman.sh/docs

┌─────────────────────────────────────────────┐
│                                             │
│   💬  Questions? Comments? Need support?    │
│                                             │
│       Join us on Discord:                   │
│       https://discord.gg/J77jBzMM           │
│                                             │
└─────────────────────────────────────────────┘
`

  let dryRunHeader = `
DRY RUN MODE - No files will be created

The following changes would be made:
`
}
