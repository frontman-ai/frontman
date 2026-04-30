// OpenTelemetry instrumentation for Frontman
// This file is automatically loaded by Next.js 15+ at startup

export async function register() {
  // Only run in Node.js runtime (not Edge)
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    // Only enable in development
    if (process.env.NODE_ENV === 'development') {
      const { NodeSDK } = await import('@opentelemetry/sdk-node');
      const { setup } = await import('@frontman-ai/nextjs/Instrumentation');

      // Setup Frontman OTEL processors (auto-initializes LogCapture)
      const [logProcessor, spanProcessor] = setup();
      const spanProcessors = [spanProcessor] as NonNullable<ConstructorParameters<typeof NodeSDK>[0]>['spanProcessors'];
      const sdkConfig = {
        logRecordProcessors: [logProcessor],
        spanProcessors,
      } as NonNullable<ConstructorParameters<typeof NodeSDK>[0]>;

      // Initialize OpenTelemetry SDK with Frontman processors
      new NodeSDK(sdkConfig).start();

      console.log('✓ Frontman instrumentation initialized');
    }
  }
}
