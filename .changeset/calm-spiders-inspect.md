---
"@frontman-ai/client": patch
"@frontman-ai/frontman-core": patch
"@frontman-ai/nextjs": patch
"@frontman-ai/vite": patch
"@frontman-ai/astro": patch
---

Give annotated elements the same bounded DOM context as `get_dom`, including their parent and direct children, so agents can follow selectors instead of broadly searching source files. Resolve Next.js React Server Component annotations through server-side source maps without issuing invalid browser requests for React's virtual source URLs, while preserving client-component source locations beneath server components.
