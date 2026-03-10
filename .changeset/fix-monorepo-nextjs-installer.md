---
"@frontman-ai/nextjs": patch
---

Fix Next.js installer failing in monorepo setups where node_modules are hoisted

- Use Node.js `createRequire` for module resolution instead of a hardcoded `node_modules/next/package.json` path
- Add `hasNextDependency` check to prevent false detection in sibling workspaces
- Remove E2E symlink workaround that was papering over the root cause
