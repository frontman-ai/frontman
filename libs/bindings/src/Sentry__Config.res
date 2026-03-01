// Shared Sentry configuration for all Frontman libraries
// Single source of truth for DSN and environment detection

// Frontman's Sentry DSN - public (client-side DSNs are always public)
let dsn = "https://442ae992e5a5ccfc42e6910220aeb2a9@o4510512511320064.ingest.de.sentry.io/4510512546185296"

// Detect Frontman team internal development (set via mprocs.yml / .dev.env)
let isInternalDev = () =>
  %raw(`typeof process !== 'undefined' && process.env?.FRONTMAN_INTERNAL_DEV === 'true'`)
