
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    if (process.env.NODE_ENV === 'development') {
      const { NodeSDK } = await import('@opentelemetry/sdk-node');
      const { setup } = await import('@frontman-ai/nextjs/Instrumentation');

      const [logProcessor, spanProcessor] = setup();
      const spanProcessors = [spanProcessor] as NonNullable<ConstructorParameters<typeof NodeSDK>[0]>['spanProcessors'];
      const sdkConfig = {
        logRecordProcessors: [logProcessor],
        spanProcessors,
      } as NonNullable<ConstructorParameters<typeof NodeSDK>[0]>;

      new NodeSDK(sdkConfig).start();

      console.log('✓ Frontman instrumentation initialized');
    }
  }
}
