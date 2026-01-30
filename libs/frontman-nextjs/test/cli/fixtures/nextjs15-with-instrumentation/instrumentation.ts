import { NodeSDK } from '@opentelemetry/sdk-node';
import { SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const sdk = new NodeSDK({
      spanProcessors: [new SimpleSpanProcessor(new OTLPTraceExporter())],
    });
    sdk.start();
  }
}
