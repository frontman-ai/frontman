let isInternalDev = () =>
  %raw(`typeof process !== 'undefined' && process.env?.FRONTMAN_INTERNAL_DEV === 'true'`)
