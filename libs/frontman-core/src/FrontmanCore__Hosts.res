// Canonical hosts and URLs for the Frontman platform.
// All integration packages (Astro, Vite, Next.js) should reference these
// instead of hardcoding domain strings.

/** The production API server host (without protocol). */
let apiHost = "api.frontman.sh"

/** The local dev API server host (without protocol). */
let devApiHost = "frontman.local:4000"

/** The production client bundle URL. */
let clientJs = "https://app.frontman.sh/frontman.es.js"

/** The production client CSS URL. */
let clientCss = "https://app.frontman.sh/frontman.css"

/** The local dev client entry point (used when developing frontman itself). */
let devClientJs = "http://localhost:5173/src/Main.res.mjs"
