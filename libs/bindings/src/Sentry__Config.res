let dsn = "https://442ae992e5a5ccfc42e6910220aeb2a9@o4510512511320064.ingest.de.sentry.io/4510512546185296"

let isInternalDev = () =>
  %raw(`typeof process !== 'undefined' && process.env?.FRONTMAN_INTERNAL_DEV === 'true'`)
