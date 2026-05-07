module CoreLogCapture = FrontmanAiFrontmanCore.FrontmanCore__LogCapture

include CoreLogCapture

let defaultConfig: config = {
  bufferCapacity: 1024,
  stdoutPatterns: ["webpack", "turbopack", "Compiled", "Failed"],
}

let getInstance = (): state => getOrCreateInstance(~config=defaultConfig)

@@live
let initialize = (~config: config=defaultConfig, ()): unit => {
  CoreLogCapture.initialize(~config, ())
}

%%raw(`
if (typeof window === 'undefined') {
  initialize();
}
`)
