---
"@frontman-ai/astro": patch
"@frontman/client": patch
---

fix(astro): load client from production CDN instead of localhost

The Astro integration defaulted `clientUrl` to `http://localhost:5173/src/Main.res.mjs` unconditionally, which only works during local frontman development. When installed from npm, users saw requests to localhost:5173 instead of the production client.

Now infers `isDev` from the host (matching the Vite plugin pattern): production host loads the client from `https://app.frontman.sh/frontman.es.js` with CSS from `https://app.frontman.sh/frontman.css`.

Also fixes the standalone client bundle crashing with `process is not defined` in browsers by replacing `process.env.NODE_ENV` at build time (Vite lib mode doesn't do this automatically).
