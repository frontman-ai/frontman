---
"@frontman/frontman-core": patch
---

fix: resolve Dependabot security vulnerabilities

Replace deprecated `vscode-ripgrep` with `@vscode/ripgrep` (same API, officially renamed package). Add yarn resolutions for 15 transitive dependencies to patch known CVEs (tar, @modelcontextprotocol/sdk, devalue, node-forge, h3, lodash, js-yaml, and others). Upgrade astro, next, and jsdom to patched versions.
