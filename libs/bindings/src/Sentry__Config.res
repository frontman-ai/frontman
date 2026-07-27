// Shared Sentry configuration for all Frontman libraries
@val external sentryDsn: option<string> = "process.env.SENTRY_DSN"

let dsn = () => sentryDsn->Option.getOrThrow

// Detect Frontman team internal development (set via mprocs.yml / .dev.env)
let isInternalDev = () =>
  %raw(`typeof process !== 'undefined' && process.env?.FRONTMAN_INTERNAL_DEV === 'true'`)
