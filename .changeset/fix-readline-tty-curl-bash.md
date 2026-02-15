---
"@frontman-ai/nextjs": patch
---

Move installer to npx-only, remove curl|bash endpoint, make --server optional

- Remove API server install endpoint (InstallController + /install routes)
- Make `--server` optional with default `api.frontman.sh`
- Simplify Readline.res: remove /dev/tty hacks, just use process.stdin
- Add `config.matcher` to proxy.ts template and auto-edit LLM rules
- Update marketing site install command from curl to `npx @frontman-ai/nextjs install`
- Update README install instructions
