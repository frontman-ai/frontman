---
"@frontman-ai/nextjs": patch
---

Support OpenTelemetry 3.x trace and log processors while retaining support for earlier SDK versions.

Keep the application's OpenTelemetry SDK in control of tracing. Frontman's Sentry client continues to report errors without registering a competing tracer provider.
