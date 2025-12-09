// Astro configuration for Frontman

type t = {
  projectRoot: string,
  basePath: string,
  serverName: string,
  serverVersion: string,
  clientUrl: string,
}

// Default client URL - can be overridden
let defaultClientUrl = "http://localhost:5173/src/Main.res.mjs"

let make = (
  ~projectRoot: string,
  ~basePath="__frontman",
  ~serverName="frontman-astro",
  ~serverVersion="1.0.0",
  ~clientUrl=defaultClientUrl,
): t => {
  projectRoot,
  basePath,
  serverName,
  serverVersion,
  clientUrl,
}
